// Firestore <-> domain model (de)serializers. These mirror the Dart
// fromJson/toJson methods exactly so web and mobile stay interoperable:
// dates are millisecondsSinceEpoch integers, enums are integer indices.

import { parseDate, parseDateOptional, toMillis } from './converters';
import type {
  Clinic,
  ClinicClientLink,
  ClinicMember,
  UserProfile,
} from './types';
import type { ClinicRole } from './enums';

type Data = Record<string, unknown>;

/* -------------------------------- UserProfile ------------------------------- */

export function userProfileFromFirestore(id: string, data: Data): UserProfile {
  return {
    id,
    email: (data.email as string) ?? '',
    displayName: (data.displayName as string) ?? '',
    userType: (data.userType as number) ?? 0,
    connectedClinicId: (data.connectedClinicId as string | null) ?? null,
    vetId: (data.vetId as string | null) ?? null,
    clinicRole:
      data.clinicRole === null || data.clinicRole === undefined
        ? null
        : (data.clinicRole as ClinicRole),
    phone: (data.phone as string | null) ?? null,
    phone2: (data.phone2 as string | null) ?? null,
    address: (data.address as string | null) ?? null,
    postalCode: (data.postalCode as string | null) ?? null,
    country: (data.country as string | null) ?? null,
    nif: (data.nif as string | null) ?? null,
    hasSkippedClinicSelection: Boolean(data.hasSkippedClinicSelection),
    mustChangePassword: Boolean(data.mustChangePassword),
    createdAt: parseDate(data.createdAt),
    updatedAt: parseDate(data.updatedAt),
    isActive: data.isActive !== false,
    globalType: (data.globalType as string | null) ?? null,
    fcmToken: (data.fcmToken as string | null) ?? null,
    invitePending: data.invitePending === true,
    invitedAt: data.invitedAt == null ? null : parseDate(data.invitedAt),
    memberOf: Array.isArray(data.memberOf) ? (data.memberOf as string[]) : [],
    clientOf: Array.isArray(data.clientOf) ? (data.clientOf as string[]) : [],
  };
}

/** Full document shape for create/overwrite (mirrors Dart UserProfile.toJson). */
export function userProfileToFirestore(p: UserProfile): Data {
  return {
    email: p.email,
    displayName: p.displayName,
    userType: p.userType,
    connectedClinicId: p.connectedClinicId ?? null,
    vetId: p.vetId ?? null,
    clinicRole: p.clinicRole ?? null,
    phone: p.phone ?? null,
    phone2: p.phone2 ?? null,
    address: p.address ?? null,
    postalCode: p.postalCode ?? null,
    country: p.country ?? null,
    nif: p.nif ?? null,
    hasSkippedClinicSelection: p.hasSkippedClinicSelection,
    mustChangePassword: p.mustChangePassword,
    createdAt: toMillis(p.createdAt),
    updatedAt: toMillis(p.updatedAt),
    isActive: p.isActive,
    globalType: p.globalType ?? null,
    fcmToken: p.fcmToken ?? null,
    invitePending: p.invitePending ?? false,
    invitedAt: p.invitedAt ? toMillis(p.invitedAt) : null,
  };
}

/* --------------------------------- Clinic --------------------------------- */

export function clinicFromFirestore(id: string, data: Data): Clinic {
  const brand = (data.brand ?? {}) as Data;
  const contact = (data.contact ?? {}) as Data;
  return {
    id,
    name: (data.name as string) ?? '',
    isActive: data.isActive !== false,
    brand: {
      primary: (brand.primary as string) ?? '',
      accent: (brand.accent as string | null) ?? null,
      logoWideUrl: (brand.logoWideUrl as string | null) ?? null,
      logoMarkUrl: (brand.logoMarkUrl as string | null) ?? null,
    },
    contact: {
      phone: (contact.phone as string | null) ?? null,
      address: (contact.address as string | null) ?? null,
      postalCode: (contact.postalCode as string | null) ?? null,
    },
    createdAt: parseDate(data.createdAt),
    updatedAt: parseDate(data.updatedAt),
  };
}

/* ------------------------------ ClinicMember ------------------------------ */

export function clinicMemberFromFirestore(data: Data): ClinicMember {
  return {
    role: data.role === 'owner' ? 'owner' : 'vet',
    displayName: (data.displayName as string) ?? '',
    email: (data.email as string) ?? '',
    active: data.active !== false,
    joinedAt: parseDate(data.joinedAt),
  };
}

/* ---------------------------- ClinicClientLink ---------------------------- */

export function clinicClientLinkFromFirestore(data: Data): ClinicClientLink {
  return {
    clientId: (data.clientId as string) ?? '',
    clientName: (data.clientName as string) ?? '',
    clinicName: (data.clinicName as string) ?? '',
    status:
      data.status === 'active' || data.status === 'declined' ? data.status : 'pending',
    addedBy: (data.addedBy as string) ?? '',
    addedByName: (data.addedByName as string) ?? '',
    addedAt: parseDate(data.addedAt),
    respondedAt: parseDateOptional(data.respondedAt) ?? null,
  };
}
