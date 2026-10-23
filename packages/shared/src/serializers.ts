// Firestore <-> domain model (de)serializers. These mirror the Dart
// fromJson/toJson methods exactly so web and mobile stay interoperable:
// dates are millisecondsSinceEpoch integers, enums are integer indices.

import { parseDate, parseDateOptional, toMillis, toMillisOptional } from './converters';
import type { UserProfile, Clinic, ClinicMember } from './types';
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
    address: (data.address as string | null) ?? null,
    hasSkippedClinicSelection: Boolean(data.hasSkippedClinicSelection),
    mustChangePassword: Boolean(data.mustChangePassword),
    createdAt: parseDate(data.createdAt),
    updatedAt: parseDate(data.updatedAt),
    isActive: data.isActive !== false,
    globalType: (data.globalType as string | null) ?? null,
    fcmToken: (data.fcmToken as string | null) ?? null,
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
    address: p.address ?? null,
    hasSkippedClinicSelection: p.hasSkippedClinicSelection,
    mustChangePassword: p.mustChangePassword,
    createdAt: toMillis(p.createdAt),
    updatedAt: toMillis(p.updatedAt),
    isActive: p.isActive,
    globalType: p.globalType ?? null,
    fcmToken: p.fcmToken ?? null,
  };
}

/* ---------------------------------- Clinic ---------------------------------- */

export function clinicFromFirestore(id: string, data: Data): Clinic {
  return {
    id,
    name: (data.name as string) ?? '',
    address: (data.address as string) ?? '',
    phone: (data.phone as string) ?? '',
    email: (data.email as string) ?? '',
    adminId: (data.adminId as string) ?? '',
    createdAt: parseDate(data.createdAt),
    updatedAt: parseDate(data.updatedAt),
    isActive: data.isActive !== false,
    website: (data.website as string | null) ?? null,
    description: (data.description as string | null) ?? null,
    businessHours: (data.businessHours as Record<string, unknown> | null) ?? null,
  };
}

export function clinicToFirestore(c: Clinic): Data {
  return {
    name: c.name,
    address: c.address,
    phone: c.phone,
    email: c.email,
    adminId: c.adminId,
    createdAt: toMillis(c.createdAt),
    updatedAt: toMillis(c.updatedAt),
    isActive: c.isActive,
    website: c.website ?? null,
    description: c.description ?? null,
    businessHours: c.businessHours ?? null,
  };
}

/* ------------------------------- ClinicMember ------------------------------- */

export function clinicMemberFromFirestore(data: Data): ClinicMember {
  return {
    userId: (data.userId as string) ?? '',
    clinicId: (data.clinicId as string) ?? '',
    role: (data.role as ClinicRole) ?? 0,
    permissions: Array.isArray(data.permissions)
      ? (data.permissions as string[])
      : [],
    addedAt: parseDate(data.addedAt),
    addedBy: (data.addedBy as string) ?? '',
    isActive: data.isActive !== false,
    lastActive: parseDateOptional(data.lastActive) ?? null,
  };
}

export function clinicMemberToFirestore(m: ClinicMember): Data {
  return {
    userId: m.userId,
    clinicId: m.clinicId,
    role: m.role,
    permissions: m.permissions,
    addedAt: toMillis(m.addedAt),
    addedBy: m.addedBy,
    isActive: m.isActive,
    lastActive: toMillisOptional(m.lastActive),
  };
}
