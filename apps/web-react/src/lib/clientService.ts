import { FirebaseError } from 'firebase/app';
import { createUserWithEmailAndPassword, sendPasswordResetEmail, signOut } from 'firebase/auth';
import { collection, doc, query, setDoc, where, type DocumentData } from 'firebase/firestore';
import {
  UserType,
  userProfileFromFirestore,
  userProfileToFirestore,
  type UserProfile,
} from '@vetplus/shared';
import { db, getSecondaryAuth } from './firebase';
import { findOrCreateOneOnOneChat } from './chatService';

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
  c.displayName?.trim() || c.email || 'Cliente';

/**
 * Vet adds a client. Creates the Auth user, writes the profile with vetId,
 * sends the set-password email, and opens the direct chat room.
 * The secondary app keeps the vet's session signed in.
 */
export async function addClientByEmail(args: {
  vetId: string;
  vetName: string;
  name: string;
  email: string;
}): Promise<string> {
  const email = args.email.trim().toLowerCase();
  const name = args.name.trim();
  if (!email || !name) throw new Error('Nome e email são obrigatórios');

  const secondary = getSecondaryAuth();
  let uid: string;
  try {
    const cred = await createUserWithEmailAndPassword(secondary, email, randomPassword());
    uid = cred.user.uid;
  } catch (e) {
    await signOut(secondary).catch(() => {});
    if (e instanceof FirebaseError && e.code === 'auth/email-already-in-use') {
      throw new Error('Esse email já tem conta.');
    }
    throw e;
  }

  const now = new Date();
  const profile: UserProfile = {
    id: uid,
    email,
    displayName: name,
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
  };

  try {
    await setDoc(doc(usersCol(), uid), userProfileToFirestore(profile));
    await sendPasswordResetEmail(secondary, email);
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
