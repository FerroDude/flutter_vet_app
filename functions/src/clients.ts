// Optional client email: a client added without one gets a profile with a
// Firestore auto-id and no Auth user. createClientLogin later creates the
// Auth user with that same uid so all existing data stays linked.

import { randomBytes } from 'node:crypto';
import { getAuth } from 'firebase-admin/auth';
import type { Firestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

const authCode = (e: unknown): string | undefined => (e as { code?: string })?.code;

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/** trim + lowercase + shape check; returns null when invalid. */
export function normalizeEmail(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const email = raw.trim().toLowerCase();
  return EMAIL_RE.test(email) ? email : null;
}

export async function createClientLogin(
  caller: string,
  data: unknown,
  db: Firestore,
): Promise<{ ok: true }> {
  const { clientId, email: rawEmail } = (data ?? {}) as {
    clientId?: unknown;
    email?: unknown;
  };
  if (typeof clientId !== 'string' || !clientId) {
    throw new HttpsError('invalid-argument', 'Falta o cliente.');
  }
  const email = normalizeEmail(rawEmail);
  if (!email) throw new HttpsError('invalid-argument', 'Email inválido.');

  const ref = db.doc(`users/${clientId}`);
  const profile = (await ref.get()).data();
  if (!profile) throw new HttpsError('not-found', 'Cliente não encontrado.');
  if (profile.userType !== 0 || profile.vetId !== caller) {
    throw new HttpsError('permission-denied', 'Cliente não encontrado.');
  }

  const auth = getAuth();
  try {
    const existing = await auth.getUser(clientId);
    if ((existing.email ?? '').toLowerCase() !== email) {
      throw new HttpsError('already-exists', 'Este cliente já tem conta com outro email.');
    }
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    if (authCode(e) !== 'auth/user-not-found') throw e;
    try {
      await auth.createUser({
        uid: clientId,
        email,
        password: randomBytes(24).toString('base64'),
        emailVerified: false,
      });
    } catch (ce) {
      if (authCode(ce) === 'auth/email-already-exists') {
        throw new HttpsError('already-exists', 'Esse email já tem conta.');
      }
      throw ce;
    }
  }

  await ref.update({ email, updatedAt: Date.now() });
  return { ok: true };
}
