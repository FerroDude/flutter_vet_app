// User profiles: users/{uid}. Dates as ms, enums as integers.

import { doc, getDoc, updateDoc } from 'firebase/firestore';
import { type UserProfile, userProfileFromFirestore, userProfileToFirestore } from '@vetplus/shared';
import { db } from './firebase';

const userDoc = (uid: string) => doc(db, 'users', uid);

export async function getUserProfile(uid: string): Promise<UserProfile | null> {
  const snap = await getDoc(userDoc(uid));
  return snap.exists() ? userProfileFromFirestore(uid, snap.data()) : null;
}

export async function updateUserProfile(profile: UserProfile): Promise<void> {
  await updateDoc(userDoc(profile.id), userProfileToFirestore(profile));
}
