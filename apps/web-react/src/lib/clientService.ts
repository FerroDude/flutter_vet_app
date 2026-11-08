import { FirebaseError } from 'firebase/app';
import { createUserWithEmailAndPassword, sendPasswordResetEmail, signOut } from 'firebase/auth';
import { collection, doc, query, setDoc, updateDoc, where, type DocumentData } from 'firebase/firestore';
import {
  UserType,
  userProfileFromFirestore,
  userProfileToFirestore,
  type UserProfile,
} from '@vetplus/shared';
import { auth, db, functions, getSecondaryAuth } from './firebase';
import { httpsCallable } from 'firebase/functions';
import { findOrCreateOneOnOneChat } from './chatService';
import { t } from '@/i18n';

const usersCol = () => collection(db, 'users');

/** Throwaway password nobody knows. The client sets their own via the reset email. */
function randomPassword(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(24));
  return btoa(String.fromCharCode(...bytes));
}

/** Clients linked to one vet. userType is filtered in useClients so this stays a single-field query. */
export function clientsQuery(vetId: string) {
  return query(usersCol(), where('vetId', '==', vetId));
}

export const mapClient = (id: string, d: DocumentData): UserProfile => userProfileFromFirestore(id, d);

export const clientLabel = (c: Pick<UserProfile, 'displayName' | 'email'>): string =>
  c.displayName?.trim() || c.email || t('common.client');

function newClientProfile(args: {
  id: string;
  name: string;
  email: string;
  vetId: string;
  invitePending: boolean;
  invitedAt: Date | null;
}): UserProfile {
  const now = new Date();
  return {
    id: args.id,
    email: args.email,
    displayName: args.name,
    userType: UserType.petOwner,
    vetId: args.vetId,
    connectedClinicId: null,
    clinicRole: null,
    phone: null,
    address: null,
    postalCode: null,
    hasSkippedClinicSelection: true,
    mustChangePassword: false,
    createdAt: now,
    updatedAt: now,
    isActive: true,
    globalType: null,
    fcmToken: null,
    invitePending: args.invitePending,
    invitedAt: args.invitedAt,
  };
}

/**
 * Vet adds a client. Email is optional:
 * - with it, the Auth user is created now (secondary app keeps the vet's
 *   session signed in) and sendInvite controls the set-password email;
 * - without it, only the profile (Firestore auto-id) + chat room are created
 *   and the vet adds the email later via addClientEmail — createClientLogin
 *   then creates the Auth user with that same uid.
 */
export async function addClient(args: {
  vetId: string;
  vetName: string;
  name: string;
  email?: string;
  sendInvite: boolean;
}): Promise<string> {
  const email = (args.email ?? '').trim().toLowerCase();
  const name = args.name.trim();
  if (!name) throw new Error(t('vet.clients.nameRequired'));

  if (!email) {
    const ref = doc(usersCol());
    const profile = newClientProfile({
      id: ref.id,
      name,
      email: '',
      vetId: args.vetId,
      invitePending: true,
      invitedAt: null,
    });
    await setDoc(ref, userProfileToFirestore(profile));
    await findOrCreateOneOnOneChat({
      petOwnerId: ref.id,
      petOwnerName: name,
      vetId: args.vetId,
      vetName: args.vetName,
    });
    return ref.id;
  }

  const secondary = getSecondaryAuth();
  let uid: string;
  try {
    const cred = await createUserWithEmailAndPassword(secondary, email, randomPassword());
    uid = cred.user.uid;
  } catch (e) {
    await signOut(secondary).catch(() => {});
    if (e instanceof FirebaseError && e.code === 'auth/email-already-in-use') {
      throw new Error(t('vet.clients.emailInUse'));
    }
    throw e;
  }

  const profile = newClientProfile({
    id: uid,
    name,
    email,
    vetId: args.vetId,
    invitePending: !args.sendInvite,
    invitedAt: args.sendInvite ? new Date() : null,
  });

  try {
    await setDoc(doc(usersCol(), uid), userProfileToFirestore(profile));
    if (args.sendInvite) await sendPasswordResetEmail(secondary, email);
    await findOrCreateOneOnOneChat({
      petOwnerId: uid,
      petOwnerName: name,
      vetId: args.vetId,
      vetName: args.vetName,
    });
  } finally {
    await signOut(secondary).catch(() => {});
  }

  return uid;
}

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

/**
 * Send (or resend) the set-password email to a client and mark the profile
 * invited. Uses the primary auth — it only emails, it never signs in.
 */
export async function sendClientInvite(client: Pick<UserProfile, 'id' | 'email'>): Promise<void> {
  await sendPasswordResetEmail(auth, client.email);
  await updateDoc(doc(usersCol(), client.id), {
    invitePending: false,
    invitedAt: Date.now(),
    updatedAt: Date.now(),
  });
}
