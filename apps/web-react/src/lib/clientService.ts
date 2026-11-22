import { sendPasswordResetEmail } from 'firebase/auth';
import { collection, doc, updateDoc, type DocumentData } from 'firebase/firestore';
import { userProfileFromFirestore, type UserProfile } from '@vetplus/shared';
import { auth, db, functions } from './firebase';
import { appLoginUrl } from './authLinks';
import { httpsCallable } from 'firebase/functions';
import { t } from '@/i18n';

const usersCol = () => collection(db, 'users');

export const mapClient = (id: string, d: DocumentData): UserProfile => userProfileFromFirestore(id, d);

export const clientLabel = (c: Pick<UserProfile, 'displayName' | 'email'>): string =>
  c.displayName?.trim() || c.email || t('common.client');

/**
 * Email added later for a client created without one. The callable creates
 * the Auth user with the same uid; sendClientInvite can then email as usual.
 */
export async function addClientEmail(clientId: string, email: string): Promise<void> {
  const call = httpsCallable<{ clientId: string; email: string }, { ok: true }>(
    functions,
    'createClientLogin',
  );
  await call({ clientId, email: email.trim().toLowerCase() });
}

export interface ClientDetails {
  phone: string | null;
  phone2: string | null;
  address: string | null;
  postalCode: string | null;
  country: string | null;
  nif: string | null;
}

/** Vet edits a client's contact details (rules allow only these keys). */
export async function updateClientDetails(clientId: string, fields: ClientDetails): Promise<void> {
  await updateDoc(doc(usersCol(), clientId), { ...fields, updatedAt: Date.now() });
}

/**
 * Send (or resend) the set-password email to a client and mark the profile
 * invited. Uses the primary auth — it only emails, it never signs in.
 */
export async function sendClientInvite(client: Pick<UserProfile, 'id' | 'email'>): Promise<void> {
  await sendPasswordResetEmail(auth, client.email, { url: appLoginUrl(client.email) });
  await updateDoc(doc(usersCol(), client.id), {
    invitePending: false,
    invitedAt: Date.now(),
    updatedAt: Date.now(),
  });
}
