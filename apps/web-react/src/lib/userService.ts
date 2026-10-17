// Firestore data layer for users + clinics. Ports the subset of the Flutter
// ClinicService used by auth/profile/linking flows. Same collection paths,
// field names and serialization (ms dates, integer enums) as mobile.

import {
  collection,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  query,
  where,
  limit as qLimit,
} from 'firebase/firestore';
import {
  type UserProfile,
  type Clinic,
  type ClinicMember,
  ClinicRole,
  UserType,
  userProfileFromFirestore,
  userProfileToFirestore,
  clinicFromFirestore,
  clinicMemberToFirestore,
  emailToken,
} from '@vetplus/shared';
import { db } from './firebase';

const usersCol = () => collection(db, 'users');
const clinicsCol = () => collection(db, 'clinics');
const membersCol = (clinicId: string) =>
  collection(db, 'clinics', clinicId, 'members');
const invitesCol = (clinicId: string) =>
  collection(db, 'clinics', clinicId, 'invites');

/* -------------------------------- User profile ------------------------------ */

export async function getUserProfile(uid: string): Promise<UserProfile | null> {
  const snap = await getDoc(doc(usersCol(), uid));
  return snap.exists() ? userProfileFromFirestore(uid, snap.data()) : null;
}

export async function createUserProfile(profile: UserProfile): Promise<void> {
  await setDoc(doc(usersCol(), profile.id), userProfileToFirestore(profile));
}

/** Overwrite the profile's mapped fields (mirrors Dart updateUserProfile). */
export async function updateUserProfile(profile: UserProfile): Promise<void> {
  await updateDoc(doc(usersCol(), profile.id), userProfileToFirestore(profile));
}

export async function deleteUserDocOnly(uid: string): Promise<void> {
  await deleteDoc(doc(usersCol(), uid));
}

/* ---------------------------------- Clinics --------------------------------- */

export async function getClinic(clinicId: string): Promise<Clinic | null> {
  const snap = await getDoc(doc(clinicsCol(), clinicId));
  return snap.exists() ? clinicFromFirestore(clinicId, snap.data()) : null;
}

export async function findClinicByAdmin(adminUserId: string): Promise<Clinic | null> {
  const snap = await getDocs(
    query(clinicsCol(), where('adminId', '==', adminUserId), qLimit(1)),
  );
  const d = snap.docs[0];
  return d ? clinicFromFirestore(d.id, d.data()) : null;
}

/** Transfer clinic ownership from a temp admin id to the real uid. */
export async function updateClinicAdminId(
  clinicId: string,
  oldAdminId: string,
  newAdminId: string,
): Promise<void> {
  const clinic = await getClinic(clinicId);
  if (clinic && clinic.adminId === oldAdminId) {
    await updateDoc(doc(clinicsCol(), clinicId), {
      adminId: newAdminId,
      updatedAt: Date.now(),
    });
  }
}

export async function searchClinics(nameQuery?: string): Promise<Clinic[]> {
  const snap = await getDocs(
    query(clinicsCol(), where('isActive', '==', true), qLimit(50)),
  );
  let clinics = snap.docs.map((d) => clinicFromFirestore(d.id, d.data()));
  if (nameQuery && nameQuery.trim()) {
    const q = nameQuery.trim().toLowerCase();
    clinics = clinics.filter((c) => c.name.toLowerCase().includes(q));
  }
  return clinics.slice(0, 20);
}

/* ------------------------------ Memberships --------------------------------- */

function membership(
  clinicId: string,
  userId: string,
  role: ClinicRole,
  permissions: string[],
): ClinicMember {
  return {
    userId,
    clinicId,
    role,
    permissions,
    addedAt: new Date(),
    addedBy: userId,
    isActive: true,
    lastActive: null,
  };
}

async function setMember(clinicId: string, member: ClinicMember): Promise<void> {
  await setDoc(
    doc(membersCol(clinicId), member.userId),
    clinicMemberToFirestore(member),
  );
}

export async function ensureAdminMembershipFor(
  clinicId: string,
  userId: string,
  tempAdminId?: string,
): Promise<void> {
  await setMember(clinicId, membership(clinicId, userId, ClinicRole.admin, ['*']));
  if (tempAdminId) {
    try {
      await deleteDoc(doc(membersCol(clinicId), tempAdminId));
    } catch {
      /* placeholder may not exist / rules — ignore */
    }
  }
}

export async function ensureVetMembershipFor(
  clinicId: string,
  userId: string,
  tempVetId?: string,
): Promise<void> {
  await setMember(clinicId, membership(clinicId, userId, ClinicRole.vet, []));
  if (tempVetId) {
    try {
      await deleteDoc(doc(membersCol(clinicId), tempVetId));
    } catch {
      /* ignore */
    }
  }
}

export async function ensureReceptionistMembershipFor(
  clinicId: string,
  userId: string,
  tempReceptionistId?: string,
): Promise<void> {
  await setMember(
    clinicId,
    membership(clinicId, userId, ClinicRole.receptionist, []),
  );
  if (tempReceptionistId) {
    try {
      await deleteDoc(doc(membersCol(clinicId), tempReceptionistId));
    } catch {
      /* ignore */
    }
  }
}

/* -------------------------------- Invites ----------------------------------- */

export async function deleteVetInvite(clinicId: string, email: string): Promise<void> {
  await deleteDoc(doc(invitesCol(clinicId), emailToken(email)));
}

/** Mirrors revokeReceptionistInvite: removes invite + temp user + temp member docs. */
export async function deleteReceptionistInvite(
  clinicId: string,
  email: string,
): Promise<void> {
  const token = emailToken(email);
  await deleteDoc(doc(invitesCol(clinicId), token));
  const tempId = `temp_receptionist_${token}`;
  try {
    await deleteDoc(doc(usersCol(), tempId));
  } catch {
    /* ignore */
  }
  try {
    await deleteDoc(doc(membersCol(clinicId), tempId));
  } catch {
    /* ignore */
  }
}

/* --------------------------- Clinic connection ------------------------------ */

export async function connectUserToClinic(
  userId: string,
  clinicId: string,
): Promise<void> {
  await updateDoc(doc(usersCol(), userId), {
    connectedClinicId: clinicId,
    updatedAt: Date.now(),
  });
  await setDoc(doc(collection(db, 'users', userId, 'clinicHistory')), {
    userId,
    clinicId,
    joinedAt: Date.now(),
  });
}

export async function disconnectUserFromClinic(userId: string): Promise<void> {
  await updateDoc(doc(usersCol(), userId), {
    connectedClinicId: null,
    clinicRole: null,
    updatedAt: Date.now(),
  });
}

/* --------------------------- Account deletion ------------------------------- */

/** Best-effort cascade delete of the user's profile + owned data subtrees. */
export async function deleteUserProfileCascade(userId: string): Promise<void> {
  // Clinic memberships across clinics
  try {
    const clinics = await getDocs(clinicsCol());
    for (const c of clinics.docs) {
      const mem = await getDocs(
        query(membersCol(c.id), where('userId', '==', userId)),
      );
      for (const m of mem.docs) await deleteDoc(m.ref);
    }
  } catch {
    /* ignore */
  }
  await deleteUserDocOnly(userId);
}

export { UserType };
