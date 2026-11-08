// Google Calendar sync (vet only): status doc + callables. The GIS popup
// code flow hands the backend an authorization code; the functions exchange
// it for a refresh token and mirror vet-booked events into a dedicated
// "Yoshi Vet Care" calendar.

import { useMemo } from 'react';
import { doc, type DocumentData } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { db, functions } from './firebase';
import { googleOAuthClientId } from './env';
import { useDoc } from './useFirestore';
import { parseDateOptional } from '@vetplus/shared';

export const gcalEnabled = Boolean(googleOAuthClientId);

export interface GcalStatus {
  connected: boolean;
  googleEmail: string | null;
  calendarId: string | null;
  connectedAt: Date | null;
  lastSyncAt: Date | null;
  lastError: string | null;
}

export function mapGcalStatus(_id: string, d: DocumentData): GcalStatus {
  return {
    connected: Boolean(d.connected),
    googleEmail: (d.googleEmail as string | null) ?? null,
    calendarId: (d.calendarId as string | null) ?? null,
    connectedAt: parseDateOptional(d.connectedAt) ?? null,
    lastSyncAt: parseDateOptional(d.lastSyncAt) ?? null,
    lastError: (d.lastError as string | null) ?? null,
  };
}

export function useGcalStatus(vetId: string) {
  const ref = useMemo(() => (vetId && gcalEnabled ? doc(db, 'gcalStatus', vetId) : null), [vetId]);
  return useDoc<GcalStatus>(ref, mapGcalStatus);
}

/* ------------------------- Google Identity Services ------------------------ */

interface GisCodeResponse {
  code?: string;
  error?: string;
}

interface GisCodeClientConfig {
  client_id: string;
  scope: string;
  ux_mode: 'popup' | 'redirect';
  // Not in the documented config type, but forwarded to the auth request:
  // needed so Google returns a refresh token on (re)connect.
  access_type?: 'offline';
  prompt?: 'consent';
  callback: (res: GisCodeResponse) => void;
  error_callback?: (err: { type?: string }) => void;
}

interface GisCodeClient {
  requestCode: () => void;
}

declare global {
  interface Window {
    google?: {
      accounts?: {
        oauth2?: {
          initCodeClient: (config: GisCodeClientConfig) => GisCodeClient;
        };
      };
    };
  }
}

const GIS_SRC = 'https://accounts.google.com/gsi/client';
let gisPromise: Promise<void> | null = null;

function loadGis(): Promise<void> {
  gisPromise ??= new Promise((resolve, reject) => {
    if (window.google?.accounts?.oauth2) return resolve();
    const script = document.createElement('script');
    script.src = GIS_SRC;
    script.async = true;
    script.onload = () => resolve();
    script.onerror = () => reject(new Error('gis_load_failed'));
    document.head.appendChild(script);
  });
  return gisPromise;
}

const GIS_SCOPE = 'openid email https://www.googleapis.com/auth/calendar.app.created';

/** Popup consent → authorization code → gcalConnect callable. */
export async function connectGcal(): Promise<{ calendarId: string; synced: number }> {
  await loadGis();
  const code = await new Promise<string>((resolve, reject) => {
    const client = window.google!.accounts!.oauth2!.initCodeClient({
      client_id: googleOAuthClientId,
      scope: GIS_SCOPE,
      ux_mode: 'popup',
      access_type: 'offline',
      prompt: 'consent',
      callback: (res) => (res.code ? resolve(res.code) : reject(new Error(res.error || 'no_code'))),
      error_callback: (err) => reject(new Error(err?.type || 'popup_closed')),
    });
    client.requestCode();
  });
  const connect = httpsCallable<{ code: string }, { calendarId: string; synced: number }>(
    functions,
    'gcalConnect',
  );
  return (await connect({ code })).data;
}

export async function syncGcal(target?: { clientId: string; eventId: string }): Promise<number> {
  const call = httpsCallable<typeof target, { synced: number }>(functions, 'gcalSyncAll');
  return (await call(target)).data.synced;
}

export async function disconnectGcal(): Promise<void> {
  const call = httpsCallable(functions, 'gcalDisconnect');
  await call();
}
