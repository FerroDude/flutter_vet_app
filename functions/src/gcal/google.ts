// Minimal Google OAuth + Calendar REST client via fetch — no googleapis
// dependency (it would double the functions bundle).

import { getFirestore } from 'firebase-admin/firestore';

const TOKEN_URL = 'https://oauth2.googleapis.com/token';
const REVOKE_URL = 'https://oauth2.googleapis.com/revoke';
const CAL_BASE = 'https://www.googleapis.com/calendar/v3';

export class GoogleApiError extends Error {
  constructor(
    message: string,
    public readonly status: number,
    public readonly googleError?: string,
  ) {
    super(message);
    this.name = 'GoogleApiError';
  }
}

/** The vet revoked access — permanent until she reconnects. */
export class RevokedGrantError extends Error {
  constructor() {
    super('invalid_grant');
    this.name = 'RevokedGrantError';
  }
}

interface TokenResponse {
  access_token?: string;
  refresh_token?: string;
  expires_in?: number;
  scope?: string;
  id_token?: string;
}

async function postForm(url: string, params: Record<string, string>): Promise<TokenResponse> {
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams(params),
  });
  const data = (await res.json().catch(() => ({}))) as TokenResponse & {
    error?: string;
    error_description?: string;
  };
  if (!res.ok) {
    throw new GoogleApiError(
      data.error_description || data.error || `HTTP ${res.status}`,
      res.status,
      data.error,
    );
  }
  return data;
}

/** Email from the id_token payload (openid email scopes were requested). */
export function decodeEmail(idToken?: string): string | null {
  if (!idToken) return null;
  const part = idToken.split('.')[1];
  if (!part) return null;
  try {
    const payload = JSON.parse(Buffer.from(part, 'base64url').toString('utf8')) as {
      email?: string;
    };
    return payload.email ?? null;
  } catch {
    return null;
  }
}

export interface ExchangedTokens {
  refreshToken: string | null;
  accessToken: string;
  scope: string | null;
  email: string | null;
}

/**
 * Exchange the GIS popup authorization code. The popup code flow uses the
 * special redirect_uri 'postmessage' for the token exchange.
 */
export async function exchangeCode(
  code: string,
  clientId: string,
  clientSecret: string,
): Promise<ExchangedTokens> {
  const data = await postForm(TOKEN_URL, {
    code,
    client_id: clientId,
    client_secret: clientSecret,
    redirect_uri: 'postmessage',
    grant_type: 'authorization_code',
  });
  if (!data.access_token) throw new GoogleApiError('no access_token in response', 0);
  return {
    refreshToken: data.refresh_token ?? null,
    accessToken: data.access_token,
    scope: data.scope ?? null,
    email: decodeEmail(data.id_token),
  };
}

const tokenCache = new Map<string, { token: string; expiresAt: number }>();

/**
 * Short-lived access token for the vet, from the stored refresh token.
 * Cached in module memory until ~60s before expiry.
 */
export async function accessToken(
  vetId: string,
  clientId: string,
  clientSecret: string,
): Promise<string> {
  const cached = tokenCache.get(vetId);
  if (cached && cached.expiresAt - 60_000 > Date.now()) return cached.token;

  const snap = await getFirestore().doc(`gcalTokens/${vetId}`).get();
  const refreshToken = snap.data()?.refreshToken as string | undefined;
  if (!refreshToken) throw new RevokedGrantError();

  let data: TokenResponse;
  try {
    data = await postForm(TOKEN_URL, {
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
      client_id: clientId,
      client_secret: clientSecret,
    });
  } catch (e) {
    if (e instanceof GoogleApiError && e.googleError === 'invalid_grant') {
      await getFirestore()
        .doc(`gcalStatus/${vetId}`)
        .set({ connected: false, lastError: 'revoked' }, { merge: true })
        .catch(() => {});
      tokenCache.delete(vetId);
      throw new RevokedGrantError();
    }
    throw e;
  }
  if (!data.access_token) throw new GoogleApiError('no access_token in response', 0);
  tokenCache.set(vetId, {
    token: data.access_token,
    expiresAt: Date.now() + (data.expires_in ?? 3600) * 1000,
  });
  return data.access_token;
}

export function clearCachedToken(vetId: string): void {
  tokenCache.delete(vetId);
}

/* ------------------------------ Calendar API ------------------------------ */

async function api(
  token: string,
  method: string,
  path: string,
  body?: unknown,
): Promise<Record<string, unknown> | null> {
  const res = await fetch(`${CAL_BASE}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (res.status === 204) return null;
  const data = (await res.json().catch(() => null)) as {
    error?: { message?: string; code?: number };
  } | null;
  if (!res.ok) {
    throw new GoogleApiError(
      data?.error?.message || `HTTP ${res.status}`,
      res.status,
      data?.error?.message ? String(data.error.code) : undefined,
    );
  }
  return data as Record<string, unknown> | null;
}

export async function createCalendar(token: string): Promise<string> {
  const cal = await api(token, 'POST', '/calendars', {
    summary: 'Yoshi Vet Care',
    timeZone: 'Europe/Lisbon',
  });
  return String(cal?.id ?? '');
}

export async function calendarExists(token: string, calendarId: string): Promise<boolean> {
  try {
    await api(token, 'GET', `/calendars/${encodeURIComponent(calendarId)}`);
    return true;
  } catch (e) {
    if (e instanceof GoogleApiError && e.status === 404) return false;
    throw e;
  }
}

/** Insert with a deterministic id; on conflict update (also revives deletes). */
export async function upsertEvent(
  token: string,
  calendarId: string,
  id: string,
  body: Record<string, unknown>,
): Promise<void> {
  const base = `/calendars/${encodeURIComponent(calendarId)}/events`;
  try {
    await api(token, 'POST', base, { ...body, id });
  } catch (e) {
    if (e instanceof GoogleApiError && e.status === 409) {
      await api(token, 'PUT', `${base}/${encodeURIComponent(id)}`, body);
      return;
    }
    throw e;
  }
}

export async function deleteEvent(
  token: string,
  calendarId: string,
  id: string,
): Promise<void> {
  try {
    await api(
      token,
      'DELETE',
      `/calendars/${encodeURIComponent(calendarId)}/events/${encodeURIComponent(id)}`,
    );
  } catch (e) {
    if (e instanceof GoogleApiError && (e.status === 404 || e.status === 410)) return;
    throw e;
  }
}

/** Revoke the refresh token when disconnecting. Best-effort by the caller. */
export async function revokeToken(refreshToken: string): Promise<void> {
  await postForm(REVOKE_URL, { token: refreshToken });
}
