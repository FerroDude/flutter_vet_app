// Pure helpers for the Google Calendar sync: deterministic event ids, the
// change-detection hash and the Calendar API event resource. No Google or
// Firebase imports so this file stays unit-testable.

import { createHash } from 'node:crypto';

/** Loose shape of users/{uid}/events/{id} as read by the functions. */
export type EventDoc = Record<string, unknown> & {
  title?: string;
  description?: string;
  location?: string | null;
  clientName?: string | null;
  petName?: string | null;
  vetName?: string | null;
  cancelReason?: string | null;
  gcal?: { eventId?: string; hash?: string; status?: string; error?: string | null };
};

/** dateTime is stored as epoch ms; very old docs may hold a Firestore Timestamp. */
export function toMs(v: unknown): number | null {
  if (typeof v === 'number' && Number.isFinite(v)) return v;
  if (v instanceof Date) return v.getTime();
  if (typeof v === 'string') {
    const ms = Date.parse(v);
    return Number.isNaN(ms) ? null : ms;
  }
  if (v && typeof v === 'object') {
    const t = v as { toMillis?: () => number; _seconds?: number; _nanoseconds?: number };
    if (typeof t.toMillis === 'function') return t.toMillis();
    if (typeof t._seconds === 'number') {
      return t._seconds * 1000 + Math.floor((t._nanoseconds ?? 0) / 1e6);
    }
  }
  return null;
}

/**
 * Deterministic Google event id per Firestore event: hex sha256 truncated to
 * 40 chars. Hex is a subset of the base32hex charset Calendar requires for
 * ids, so an insert can never collide or duplicate across resyncs.
 */
export function googleEventId(clientId: string, eventId: string): string {
  return createHash('sha256').update(`${clientId}/${eventId}`).digest('hex').slice(0, 40);
}

/** Hash of only the fields the Google event mirrors — used as loop guard. */
export function syncHash(data: EventDoc): string {
  const synced = {
    title: data.title ?? '',
    description: data.description ?? '',
    dateTime: toMs(data.dateTime),
    location: data.location ?? null,
    clientName: data.clientName ?? null,
    petName: data.petName ?? null,
    cancelledAt: toMs(data.cancelledAt),
    cancelReason: data.cancelReason ?? null,
    vetName: data.vetName ?? null,
  };
  return createHash('sha256').update(JSON.stringify(synced)).digest('hex');
}

export interface GoogleEventResource {
  id?: string;
  status: 'confirmed';
  summary: string;
  description?: string;
  location?: string;
  colorId?: string;
  start: { dateTime: string; timeZone: string };
  end: { dateTime: string; timeZone: string };
  extendedProperties: { private: Record<string, string> };
}

const TZ = 'Europe/Lisbon';
const HALF_HOUR = 30 * 60 * 1000;

export function buildGoogleEvent(
  data: EventDoc,
  ids: { clientId: string; eventId: string; appUrl: string },
): GoogleEventResource {
  const start = toMs(data.dateTime) ?? Date.now();
  const cancelled = toMs(data.cancelledAt) != null;
  // Default titles already carry the pet ("Consulta — Luna"); don't repeat it.
  const showPet = Boolean(data.petName) && !String(data.title ?? '').includes(String(data.petName));
  const summary =
    `${cancelled ? 'CANCELADA · ' : ''}${data.title ?? ''} · ` +
    `${data.clientName || 'Cliente'}${showPet ? ` (${data.petName})` : ''}`;

  const descLines: string[] = [];
  if (data.description) descLines.push(String(data.description));
  if (cancelled && data.cancelReason) {
    descLines.push(`Motivo do cancelamento: ${data.cancelReason}`);
  }
  descLines.push(ids.appUrl);

  const event: GoogleEventResource = {
    status: 'confirmed',
    summary,
    start: { dateTime: new Date(start).toISOString(), timeZone: TZ },
    end: { dateTime: new Date(start + HALF_HOUR).toISOString(), timeZone: TZ },
    extendedProperties: {
      private: { vetplusClientId: ids.clientId, vetplusEventId: ids.eventId },
    },
  };
  if (data.location) event.location = String(data.location);
  if (descLines.length) event.description = descLines.join('\n');
  if (cancelled) event.colorId = '8';
  return event;
}
