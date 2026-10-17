// Port of the Flutter UserProvider account-linking logic
// (_loadUserProfile + _createInitialUserProfile). Resolves the Firestore
// profile for a freshly authenticated user, promoting temp_admin_/temp_vet_/
// temp_receptionist_ placeholders created during invite flows into the real
// account, and creating an initial pet-owner profile for brand-new users.
//
// Keep behaviour in lockstep with apps/mobile-flutter/lib/providers/user_provider.dart
// so web and mobile interoperate.

import type { User } from 'firebase/auth';
import {
  type UserProfile,
  UserType,
  ClinicRole,
  isAppOwnerEmail,
  emailToken,
} from '@vetplus/shared';
import * as svc from '@/lib/userService';

function tempIds(email: string) {
  const token = emailToken(email);
  return {
    admin: `temp_admin_${token}`,
    vet: `temp_vet_${token}`,
    receptionist: `temp_receptionist_${token}`,
  };
}

/** Resolve (and link/create as needed) the profile for a verified user. */
export async function resolveUserProfile(user: User): Promise<UserProfile | null> {
  const uid = user.uid;
  const profile = await svc.getUserProfile(uid);

  if (profile) {
    return linkExistingProfile(user, profile);
  }
  return createInitialUserProfile(user);
}

async function linkExistingProfile(
  user: User,
  profileIn: UserProfile,
): Promise<UserProfile> {
  let profile = profileIn;
  const email = (user.email ?? '').trim();

  // Upgrade an existing user to app owner if their email is in the list.
  if (isAppOwnerEmail(email) && profile.globalType !== 'appOwner') {
    profile = { ...profile, globalType: 'appOwner', updatedAt: new Date() };
    await svc.updateUserProfile(profile);
  }

  // Only check for temp invite profiles if the user isn't already staff.
  const notStaff =
    profile.userType !== UserType.clinicAdmin &&
    profile.userType !== UserType.vet &&
    profile.userType !== UserType.receptionist;

  if (email && notStaff) {
    const ids = tempIds(email);

    const tempAdmin = await svc.getUserProfile(ids.admin);
    if (
      tempAdmin &&
      tempAdmin.userType === UserType.clinicAdmin &&
      tempAdmin.connectedClinicId
    ) {
      const clinicId = tempAdmin.connectedClinicId;
      await svc.ensureAdminMembershipFor(clinicId, profile.id, ids.admin);
      await svc.updateClinicAdminId(clinicId, ids.admin, profile.id);
      profile = {
        ...profile,
        userType: UserType.clinicAdmin,
        clinicRole: ClinicRole.admin,
        connectedClinicId: clinicId,
        displayName: tempAdmin.displayName,
        updatedAt: new Date(),
      };
      await svc.updateUserProfile(profile);
      await safe(() => svc.deleteUserDocOnly(ids.admin));
      return profile;
    }

    const tempVet = await svc.getUserProfile(ids.vet);
    if (tempVet && tempVet.userType === UserType.vet && tempVet.connectedClinicId) {
      const clinicId = tempVet.connectedClinicId;
      await svc.ensureVetMembershipFor(clinicId, profile.id, ids.vet);
      profile = {
        ...profile,
        userType: UserType.vet,
        clinicRole: ClinicRole.vet,
        connectedClinicId: clinicId,
        displayName: '', // vet sets their own on first login
        updatedAt: new Date(),
      };
      await svc.updateUserProfile(profile);
      await safe(() => svc.deleteVetInvite(clinicId, email));
      await safe(() => svc.deleteUserDocOnly(ids.vet));
      return profile;
    }

    const tempRec = await svc.getUserProfile(ids.receptionist);
    if (
      tempRec &&
      tempRec.userType === UserType.receptionist &&
      tempRec.connectedClinicId
    ) {
      const clinicId = tempRec.connectedClinicId;
      await svc.ensureReceptionistMembershipFor(clinicId, profile.id, ids.receptionist);
      profile = {
        ...profile,
        userType: UserType.receptionist,
        clinicRole: ClinicRole.receptionist,
        connectedClinicId: clinicId,
        displayName: '', // receptionist sets their own on first login
        updatedAt: new Date(),
      };
      await svc.updateUserProfile(profile);
      await safe(() => svc.deleteReceptionistInvite(clinicId, email));
      await safe(() => svc.deleteUserDocOnly(ids.receptionist));
      return profile;
    }
  }

  return profile;
}

async function createInitialUserProfile(user: User): Promise<UserProfile> {
  const now = new Date();
  const email = (user.email ?? '').trim();
  const ids = tempIds(email);

  let userType = UserType.petOwner;
  const globalType = isAppOwnerEmail(email) ? 'appOwner' : null;
  let connectedClinicId: string | null = null;
  let clinicRole: ClinicRole | null = null;
  let templateName: string | null = null;

  const tempAdmin = await svc.getUserProfile(ids.admin);
  if (tempAdmin && tempAdmin.userType === UserType.clinicAdmin) {
    userType = UserType.clinicAdmin;
    connectedClinicId = tempAdmin.connectedClinicId ?? null;
    clinicRole = ClinicRole.admin;
    templateName = tempAdmin.displayName;
    if (connectedClinicId) {
      await svc.ensureAdminMembershipFor(connectedClinicId, user.uid, ids.admin);
      await svc.updateClinicAdminId(connectedClinicId, ids.admin, user.uid);
    }
    await safe(() => svc.deleteUserDocOnly(ids.admin));
  } else {
    const tempVet = await svc.getUserProfile(ids.vet);
    if (tempVet && tempVet.userType === UserType.vet) {
      userType = UserType.vet;
      connectedClinicId = tempVet.connectedClinicId ?? null;
      clinicRole = ClinicRole.vet;
      if (connectedClinicId) {
        await svc.ensureVetMembershipFor(connectedClinicId, user.uid, ids.vet);
        await safe(() => svc.deleteVetInvite(connectedClinicId!, email));
      }
    } else {
      const tempRec = await svc.getUserProfile(ids.receptionist);
      if (tempRec && tempRec.userType === UserType.receptionist) {
        userType = UserType.receptionist;
        connectedClinicId = tempRec.connectedClinicId ?? null;
        clinicRole = ClinicRole.receptionist;
        if (connectedClinicId) {
          await svc.ensureReceptionistMembershipFor(
            connectedClinicId,
            user.uid,
            ids.receptionist,
          );
          await safe(() => svc.deleteReceptionistInvite(connectedClinicId!, email));
        }
      }
    }
  }

  let displayName: string;
  if (userType === UserType.clinicAdmin && templateName !== null) {
    displayName = templateName;
  } else if (userType === UserType.vet || userType === UserType.receptionist) {
    displayName = ''; // staff set their own
  } else {
    displayName = user.displayName ?? 'User';
  }

  const profile: UserProfile = {
    id: user.uid,
    email,
    displayName,
    userType,
    connectedClinicId,
    clinicRole,
    phone: null,
    address: null,
    hasSkippedClinicSelection: false,
    mustChangePassword: false,
    createdAt: now,
    updatedAt: now,
    isActive: true,
    globalType,
    fcmToken: null,
  };

  await svc.createUserProfile(profile);

  // Clean up temp docs AFTER the real profile exists.
  if (userType === UserType.vet) await safe(() => svc.deleteUserDocOnly(ids.vet));
  if (userType === UserType.receptionist)
    await safe(() => svc.deleteUserDocOnly(ids.receptionist));

  return profile;
}

async function safe(fn: () => Promise<unknown>): Promise<void> {
  try {
    await fn();
  } catch {
    /* best-effort cleanup, matches Dart's swallowed errors */
  }
}
