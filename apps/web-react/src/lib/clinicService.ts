// Clinic-side data layer for staff (vet / receptionist / admin / app owner).
// Mirrors the subset of the Flutter ClinicService + UserProvider used by staff
// screens. Collection paths + field names match mobile; dates as ms, enums as
// int indices. Invited staff get a temp user + temp member doc (so linking.ts
// can promote them on first sign-in) plus an Auth account via the secondary app.

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
  type DocumentData,
} from 'firebase/firestore';
import {
  createUserWithEmailAndPassword,
  sendPasswordResetEmail,
  signOut,
} from 'firebase/auth';
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
  isPetOwner,
} from '@vetplus/shared';
import { auth, db, getSecondaryAuth } from './firebase';

const usersCol = () => collection(db, 'users');
const clinicsCol = () => collection(db, 'clinics');
const membersCol = (clinicId: string) => collection(db, 'clinics', clinicId, 'members');
const invitesCol = (clinicId: string) => collection(db, 'clinics', clinicId, 'invites');

/* --------------------------------- Patients --------------------------------- */

/**
 * Pet owners connected to a clinic. Mirrors Flutter's clinicPatientsStream:
 * filters `userType == petOwner` server-side. This is REQUIRED for non-admin
 * staff (vets/receptionists) — the Firestore rules only let them read pet-owner
 * profiles in their clinic, so a query that also returned staff/temp docs would
 * be rejected wholesale (and silently come back empty). Two equality filters
 * need no composite index; sort/search happens client-side.
 */
export function clinicPatientsQuery(clinicId: string) {
  return query(
    usersCol(),
    where('connectedClinicId', '==', clinicId),
    where('userType', '==', UserType.petOwner),
  );
}

export function mapPatient(id: string, d: DocumentData): UserProfile {
  return userProfileFromFirestore(id, d);
}

/** Keep only real pet-owner accounts (temp/staff docs can share the field). */
export function isPatient(p: UserProfile): boolean {
  return isPetOwner(p) && !p.id.startsWith('temp_');
}

/* ---------------------------------- Clinic ---------------------------------- */

export interface ClinicEditableFields {
  name: string;
  address: string;
  phone: string;
  email: string;
  website?: string | null;
  description?: string | null;
  businessHours?: Record<string, unknown> | null;
}

/** Update editable clinic fields (admin / app owner). */
export async function updateClinic(
  clinicId: string,
  fields: ClinicEditableFields,
): Promise<void> {
  await updateDoc(doc(clinicsCol(), clinicId), {
    name: fields.name.trim(),
    address: fields.address.trim(),
    phone: fields.phone.trim(),
    email: fields.email.trim(),
    website: fields.website?.trim() ? fields.website.trim() : null,
    description: fields.description?.trim() ? fields.description.trim() : null,
    businessHours: fields.businessHours ?? null,
    updatedAt: Date.now(),
  });
}

/* -------------------------------- Staff members ----------------------------- */

/** All users linked to a clinic (admins only — they can read every clinic-linked
 *  profile per the rules). Filter to active staff client-side. */
export function clinicMembersQuery(clinicId: string) {
  return query(usersCol(), where('connectedClinicId', '==', clinicId));
}

export function isActiveStaff(p: UserProfile): boolean {
  return (
    !p.id.startsWith('temp_') &&
    p.isActive &&
    (p.clinicRole === ClinicRole.vet || p.clinicRole === ClinicRole.receptionist)
  );
}

/** Soft-remove a staff member: deactivate their membership and unlink them. */
export async function removeStaffMember(clinicId: string, userId: string): Promise<void> {
  try {
    await updateDoc(doc(membersCol(clinicId), userId), {
      isActive: false,
      lastActive: Date.now(),
    });
  } catch {
    /* member doc may not exist — ignore */
  }
  try {
    await updateDoc(doc(usersCol(), userId), {
      connectedClinicId: null,
      clinicRole: null,
      updatedAt: Date.now(),
    });
  } catch {
    /* ignore */
  }
}

/* ----------------------------------- Invites -------------------------------- */

export type InviteRole = 'vet' | 'receptionist';

export interface ClinicInvite {
  id: string; // emailToken
  email: string;
  role: InviteRole;
  status: string;
  createdAt: Date;
  invitedBy: string | null;
}

/** All invites for a clinic; filter by role / sort client-side (small set). */
export function clinicInvitesQuery(clinicId: string) {
  return query(invitesCol(clinicId));
}

export function mapInvite(id: string, d: DocumentData): ClinicInvite {
  const created = d.createdAt;
  const createdAt =
    typeof created === 'number'
      ? new Date(created)
      : created && typeof created.toDate === 'function'
        ? (created.toDate() as Date)
        : new Date();
  return {
    id,
    email: (d.email as string) ?? '',
    role: ((d.role as string) === 'receptionist' ? 'receptionist' : 'vet') as InviteRole,
    status: (d.status as string) ?? 'pending',
    createdAt,
    invitedBy: (d.invitedBy as string | null) ?? null,
  };
}

function userTypeFor(role: InviteRole): UserType {
  return role === 'vet' ? UserType.vet : UserType.receptionist;
}
function clinicRoleFor(role: InviteRole): ClinicRole {
  return role === 'vet' ? ClinicRole.vet : ClinicRole.receptionist;
}
function tempIdFor(role: InviteRole, token: string): string {
  return `temp_${role}_${token}`;
}

/**
 * Invite a vet/receptionist by email. Mirrors Flutter ClinicService.createVetInvite
 * + UserProvider.inviteVetByEmail: writes the invite doc, a temp user profile and
 * a temp (inactive) membership so linking.ts can promote them on first sign-in,
 * then provisions an Auth account + password-reset email via the secondary app.
 */
export async function inviteStaffByEmail(args: {
  clinicId: string;
  email: string;
  role: InviteRole;
  invitedBy: string;
}): Promise<void> {
  const email = args.email.trim().toLowerCase();
  if (!email) throw new Error('Email is required');
  const token = emailToken(email);
  const tempId = tempIdFor(args.role, token);
  const now = Date.now();

  await setDoc(doc(invitesCol(args.clinicId), token), {
    email,
    role: args.role,
    status: 'pending',
    createdAt: now,
    invitedBy: args.invitedBy,
  });

  const tempProfile: UserProfile = {
    id: tempId,
    email,
    displayName: email,
    userType: userTypeFor(args.role),
    connectedClinicId: args.clinicId,
    clinicRole: clinicRoleFor(args.role),
    phone: null,
    address: null,
    hasSkippedClinicSelection: false,
    mustChangePassword: false,
    createdAt: new Date(now),
    updatedAt: new Date(now),
    isActive: false,
    globalType: null,
    fcmToken: null,
  };
  await setDoc(doc(usersCol(), tempId), userProfileToFirestore(tempProfile));

  const tempMember: ClinicMember = {
    userId: tempId,
    clinicId: args.clinicId,
    role: clinicRoleFor(args.role),
    permissions: [],
    addedAt: new Date(now),
    addedBy: args.invitedBy,
    isActive: false,
    lastActive: null,
  };
  await setDoc(doc(membersCol(args.clinicId), tempId), clinicMemberToFirestore(tempMember));

  await provisionAuthAccountAndSendReset(email).catch(() => false);
}

/** Revoke an invite: remove invite doc + temp user + temp membership. */
export async function revokeStaffInvite(args: {
  clinicId: string;
  email: string;
  role: InviteRole;
}): Promise<void> {
  const token = emailToken(args.email.trim().toLowerCase());
  const tempId = tempIdFor(args.role, token);
  await deleteDoc(doc(invitesCol(args.clinicId), token)).catch(() => {});
  await deleteDoc(doc(usersCol(), tempId)).catch(() => {});
  await deleteDoc(doc(membersCol(args.clinicId), tempId)).catch(() => {});
}

/** Re-send the password-reset / provisioning email for a pending invite. */
export async function resendInvite(email: string): Promise<boolean> {
  return provisionAuthAccountAndSendReset(email.trim().toLowerCase());
}

/**
 * Create an Auth account (if needed) for an invited email and send a reset link,
 * using the secondary app so the current admin's session is untouched.
 * Mirrors UserProvider.provisionAuthAccountAndSendReset.
 */
export async function provisionAuthAccountAndSendReset(email: string): Promise<boolean> {
  const secondary = getSecondaryAuth();
  try {
    await createUserWithEmailAndPassword(secondary, email, 'TempPassword123!');
  } catch {
    /* email-already-in-use (or other) — fall through to reset */
  }
  try {
    await sendPasswordResetEmail(secondary, email);
  } catch {
    try {
      await sendPasswordResetEmail(auth, email);
    } catch {
      return false;
    }
  } finally {
    await signOut(secondary).catch(() => {});
  }
  return true;
}

/* ------------------------------ Clinic creation ----------------------------- */

export interface NewClinicForAdmin extends ClinicEditableFields {
  adminEmail: string;
  adminName: string;
}

/**
 * App-owner flow: create a clinic owned by a (possibly not-yet-registered) admin.
 * Mirrors UserProvider.createClinicForAdmin — creates the clinic with a temp
 * admin id, a temp admin user profile, an admin membership, and provisions the
 * admin's Auth account + reset email. linking.ts promotes the temp admin on
 * first sign-in. Returns the new clinic id.
 */
export async function createClinicForAdmin(input: NewClinicForAdmin): Promise<string> {
  const adminEmail = input.adminEmail.trim().toLowerCase();
  if (!adminEmail) throw new Error('Admin email is required');
  const token = emailToken(adminEmail);
  const tempAdminId = `temp_admin_${token}`;
  const now = Date.now();

  const clinicRef = doc(clinicsCol());
  await setDoc(clinicRef, {
    name: input.name.trim(),
    address: input.address.trim(),
    phone: input.phone.trim(),
    email: input.email.trim(),
    adminId: tempAdminId,
    createdAt: now,
    updatedAt: now,
    isActive: true,
    website: input.website?.trim() ? input.website.trim() : null,
    description: input.description?.trim() ? input.description.trim() : null,
    businessHours: input.businessHours ?? null,
  });

  const tempAdmin: UserProfile = {
    id: tempAdminId,
    email: adminEmail,
    displayName: input.adminName.trim() || adminEmail,
    userType: UserType.clinicAdmin,
    connectedClinicId: clinicRef.id,
    clinicRole: ClinicRole.admin,
    phone: null,
    address: null,
    hasSkippedClinicSelection: false,
    mustChangePassword: false,
    createdAt: new Date(now),
    updatedAt: new Date(now),
    isActive: false,
    globalType: null,
    fcmToken: null,
  };
  await setDoc(doc(usersCol(), tempAdminId), userProfileToFirestore(tempAdmin));

  const adminMember: ClinicMember = {
    userId: tempAdminId,
    clinicId: clinicRef.id,
    role: ClinicRole.admin,
    permissions: ['*'],
    addedAt: new Date(now),
    addedBy: tempAdminId,
    isActive: false,
    lastActive: null,
  };
  await setDoc(doc(membersCol(clinicRef.id), tempAdminId), clinicMemberToFirestore(adminMember));

  await provisionAuthAccountAndSendReset(adminEmail).catch(() => false);
  return clinicRef.id;
}

/* ------------------------------- App owner ---------------------------------- */

/** All clinics (app owner). Sort client-side. */
export function allClinicsQuery() {
  return query(clinicsCol());
}

export function mapClinic(id: string, d: DocumentData): Clinic {
  return clinicFromFirestore(id, d);
}

/** All users (app owner stats). Sort/aggregate client-side. */
export function allUsersQuery() {
  return query(usersCol());
}

/**
 * App-owner cascade delete of a clinic: unlink its members + pet owners, remove
 * member/invite docs, then delete the clinic. Mirrors ClinicService.deleteClinicAsOwner.
 */
export async function deleteClinicAsOwner(clinicId: string): Promise<void> {
  // Unlink + remove memberships
  try {
    const members = await getDocs(membersCol(clinicId));
    for (const m of members.docs) {
      const userId = (m.data().userId as string) ?? m.id;
      if (userId && !userId.startsWith('temp_')) {
        await updateDoc(doc(usersCol(), userId), {
          connectedClinicId: null,
          clinicRole: null,
          updatedAt: Date.now(),
        }).catch(() => {});
      }
      await deleteDoc(m.ref).catch(() => {});
    }
  } catch {
    /* ignore */
  }
  // Unlink pet owners still pointing at this clinic
  try {
    const owners = await getDocs(clinicPatientsQuery(clinicId));
    for (const o of owners.docs) {
      await updateDoc(o.ref, { connectedClinicId: null, updatedAt: Date.now() }).catch(() => {});
    }
  } catch {
    /* ignore */
  }
  // Remove invites
  try {
    const invites = await getDocs(invitesCol(clinicId));
    for (const i of invites.docs) await deleteDoc(i.ref).catch(() => {});
  } catch {
    /* ignore */
  }
  await deleteDoc(doc(clinicsCol(), clinicId));
}

/* --------------------------------- Read helpers ----------------------------- */

export async function getClinic(clinicId: string): Promise<Clinic | null> {
  const snap = await getDoc(doc(clinicsCol(), clinicId));
  return snap.exists() ? clinicFromFirestore(clinicId, snap.data()) : null;
}
