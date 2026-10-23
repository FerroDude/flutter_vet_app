// Resolves the Firestore profile for a signed-in user.
// Accounts are never created here: vets are provisioned with
// scripts/create-vet.mjs and clients are added by their vet. A signed-in user
// without a profile has no access.

import type { User } from 'firebase/auth';
import type { UserProfile } from '@vetplus/shared';
import * as svc from '@/lib/userService';

export async function resolveUserProfile(user: User): Promise<UserProfile | null> {
  return svc.getUserProfile(user.uid);
}
