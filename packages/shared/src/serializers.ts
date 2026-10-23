// Firestore <-> domain model (de)serializers. These mirror the Dart
// fromJson/toJson methods exactly so web and mobile stay interoperable:
// dates are millisecondsSinceEpoch integers, enums are integer indices.

import { parseDate, toMillis } from './converters';
import type { UserProfile } from './types';
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
