// Sync one Firestore event to the vet's "Yoshi Vet Care" Google calendar and
// write the outcome back onto the event doc (field `gcal`).

import { getFirestore } from 'firebase-admin/firestore';
import { buildGoogleEvent, googleEventId, syncHash, type EventDoc } from './event.js';
import { deleteEvent, upsertEvent } from './google.js';

export const APP_URL = 'https://ferrodude.github.io/flutter_vet_app/agenda';

export interface SyncCtx {
  vetId: string;
  token: string;
  calendarId: string;
}

const shortError = (e: unknown): string =>
  (e instanceof Error ? e.message : String(e)).slice(0, 200);

/**
 * data === null means the Firestore event was deleted → remove the Google
 * event. Otherwise upsert and stamp `gcal` on the doc. Failures are recorded
 * (with the attempted hash so the trigger doesn't hot-loop) instead of thrown.
 */
export async function syncEvent(
  ctx: SyncCtx,
  clientId: string,
  eventId: string,
  data: EventDoc | null,
): Promise<void> {
  const db = getFirestore();
  const gid = data?.gcal?.eventId || googleEventId(clientId, eventId);
  const hash = data ? syncHash(data) : '';

  try {
    if (data === null) {
      await deleteEvent(ctx.token, ctx.calendarId, gid);
      return;
    }
    const body = buildGoogleEvent(data, { clientId, eventId, appUrl: APP_URL });
    await upsertEvent(ctx.token, ctx.calendarId, gid, body as unknown as Record<string, unknown>);
    await db.doc(`users/${clientId}/events/${eventId}`).update({
      gcal: { eventId: gid, status: 'synced', syncedAt: Date.now(), hash, error: null },
    });
  } catch (e) {
    const msg = shortError(e);
    if (data !== null) {
      await db
        .doc(`users/${clientId}/events/${eventId}`)
        .update({
          gcal: { eventId: gid, status: 'error', syncedAt: Date.now(), hash, error: msg },
        })
        .catch(() => {});
    }
    await db
      .doc(`gcalStatus/${ctx.vetId}`)
      .set({ lastError: msg }, { merge: true })
      .catch(() => {});
    throw e;
  }
}
