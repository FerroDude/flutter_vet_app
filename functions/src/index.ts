// Google Calendar sync for the vet (project vetplus-digital, us-central1).
// One "Yoshi Vet Care" calendar in her Google account; every event she books
// in a client's calendar (bookedByVetId) is mirrored there. Firestore stays
// the source of truth; `gcal` on the event doc records the sync state.

import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { setGlobalOptions } from 'firebase-functions/v2';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { defineSecret, defineString } from 'firebase-functions/params';
import { syncHash, toMs, type EventDoc } from './gcal/event.js';
import {
  accessToken,
  calendarExists,
  createCalendar,
  clearCachedToken,
  exchangeCode,
  revokeToken,
} from './gcal/google.js';
import { syncEvent } from './gcal/sync.js';

initializeApp();
const db = () => getFirestore();

const GOOGLE_CLIENT_ID = defineString('GOOGLE_OAUTH_CLIENT_ID');
const GOOGLE_CLIENT_SECRET = defineSecret('GOOGLE_OAUTH_CLIENT_SECRET');

setGlobalOptions({
  region: 'us-central1',
  memory: '256MiB',
  minInstances: 0,
  maxInstances: 2,
});

const DAY_MS = 86_400_000;

async function requireVet(request: { auth?: { uid?: string } | null }): Promise<string> {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Inicie sessão.');
  const snap = await db().doc(`users/${uid}`).get();
  if (snap.data()?.userType !== 1) {
    throw new HttpsError('permission-denied', 'Só a veterinária pode ligar o Google Calendar.');
  }
  return uid;
}

async function syncCtx(vetId: string) {
  const status = (await db().doc(`gcalStatus/${vetId}`).get()).data();
  if (!status?.connected || !status.calendarId) {
    throw new HttpsError('failed-precondition', 'O Google Calendar não está ligado.');
  }
  const token = await accessToken(vetId, GOOGLE_CLIENT_ID.value(), GOOGLE_CLIENT_SECRET.value());
  return { vetId, token, calendarId: status.calendarId as string };
}

/** Sync every upcoming vet-booked event (from yesterday on), sequentially. */
async function backfill(ctx: { vetId: string; token: string; calendarId: string }): Promise<number> {
  const snap = await db()
    .collectionGroup('events')
    .where('bookedByVetId', '==', ctx.vetId)
    .get();
  const since = Date.now() - DAY_MS;
  let synced = 0;
  for (const doc of snap.docs) {
    const data = doc.data() as EventDoc;
    const ms = toMs(data.dateTime);
    if (ms !== null && ms < since) continue;
    const clientId = doc.ref.parent.parent!.id;
    try {
      await syncEvent(ctx, clientId, doc.id, data);
      synced++;
    } catch {
      /* error recorded on the doc; keep going */
    }
  }
  await db()
    .doc(`gcalStatus/${ctx.vetId}`)
    .set({ lastSyncAt: Date.now() }, { merge: true })
    .catch(() => {});
  return synced;
}

/**
 * Any write under users/{clientId}/events/{eventId} for a vet-booked event
 * (book, edit, client cancel, delete) mirrors into Google. The hash guard
 * skips our own `gcal` write-back and writes that change nothing we sync.
 */
export const gcalOnEventWrite = onDocumentWritten(
  { document: 'users/{clientId}/events/{eventId}', secrets: [GOOGLE_CLIENT_SECRET] },
  async (event) => {
    const before = event.data?.before.data() as EventDoc | undefined;
    const after = event.data?.after.data() as EventDoc | undefined;
    const vetId = (after ?? before)?.bookedByVetId as string | undefined;
    if (!vetId) return;
    if (after && after.gcal?.hash && after.gcal.hash === syncHash(after)) return;

    const { clientId, eventId } = event.params;
    const status = (await db().doc(`gcalStatus/${vetId}`).get()).data();
    if (!status?.connected || !status.calendarId) return;

    const ctx = {
      vetId,
      token: await accessToken(vetId, GOOGLE_CLIENT_ID.value(), GOOGLE_CLIENT_SECRET.value()),
      calendarId: status.calendarId as string,
    };
    try {
      await syncEvent(ctx, clientId, eventId, after ?? null);
    } catch {
      /* error already recorded on the doc/status */
    }
  },
);

/** First connect: exchange the GIS code, create/find the calendar, backfill. */
export const gcalConnect = onCall(
  { secrets: [GOOGLE_CLIENT_SECRET], maxInstances: 1 },
  async (request) => {
    const uid = await requireVet(request);
    const code = request.data?.code;
    if (typeof code !== 'string' || !code) {
      throw new HttpsError('invalid-argument', 'Falta o código de autorização.');
    }

    const tokens = await exchangeCode(
      code,
      GOOGLE_CLIENT_ID.value(),
      GOOGLE_CLIENT_SECRET.value(),
    );
    if (!tokens.refreshToken) {
      throw new HttpsError('failed-precondition', 'Sem acesso offline — tente de novo.');
    }

    await db().doc(`gcalTokens/${uid}`).set({
      refreshToken: tokens.refreshToken,
      scope: tokens.scope ?? '',
      connectedAt: Date.now(),
    });

    let calendarId = ((await db().doc(`gcalStatus/${uid}`).get()).data()?.calendarId ??
      null) as string | null;
    if (calendarId && !(await calendarExists(tokens.accessToken, calendarId))) {
      calendarId = null;
    }
    calendarId ??= await createCalendar(tokens.accessToken);

    await db().doc(`gcalStatus/${uid}`).set(
      {
        connected: true,
        googleEmail: tokens.email,
        calendarId,
        connectedAt: Date.now(),
        lastError: null,
      },
      { merge: true },
    );

    const synced = await backfill({ vetId: uid, token: tokens.accessToken, calendarId });
    return { calendarId, synced };
  },
);

/** Re-sync everything (or one event with {clientId, eventId}). */
export const gcalSyncAll = onCall(
  { secrets: [GOOGLE_CLIENT_SECRET], maxInstances: 1 },
  async (request) => {
    const uid = await requireVet(request);
    const ctx = await syncCtx(uid);

    const { clientId, eventId } = (request.data ?? {}) as {
      clientId?: string;
      eventId?: string;
    };
    if (clientId && eventId) {
      const snap = await db().doc(`users/${clientId}/events/${eventId}`).get();
      const data = snap.data() as EventDoc | undefined;
      if (!snap.exists || data?.bookedByVetId !== uid) {
        throw new HttpsError('not-found', 'Consulta não encontrada.');
      }
      await syncEvent(ctx, clientId, eventId, data!);
      return { synced: 1 };
    }

    const synced = await backfill(ctx);
    return { synced };
  },
);

/** Revoke + forget the grant. The Google calendar itself is left alone. */
export const gcalDisconnect = onCall({ maxInstances: 1 }, async (request) => {
  const uid = await requireVet(request);
  const refreshToken = (await db().doc(`gcalTokens/${uid}`).get()).data()?.refreshToken as
    | string
    | undefined;
  if (refreshToken) {
    await revokeToken(refreshToken).catch(() => {});
  }
  clearCachedToken(uid);
  await db().doc(`gcalTokens/${uid}`).delete().catch(() => {});
  // Keep calendarId so a reconnect reuses the same calendar.
  await db()
    .doc(`gcalStatus/${uid}`)
    .set({ connected: false, lastError: null }, { merge: true });
  return { disconnected: true };
});
