// Appointment requests data layer (pet owner -> clinic). Mirrors
// apps/mobile-flutter/lib/services/appointment_request_service.dart and
// appointment_request_model.dart.
//
// Storage: top-level `appointmentRequests/{id}`.
// Interop: dates as millisecondsSinceEpoch, `timePreference` and `status` as
// the integer enum indices from @vetplus/shared.

import {
  collection,
  doc,
  addDoc,
  updateDoc,
  runTransaction,
  query,
  where,
  type DocumentData,
} from 'firebase/firestore';
import {
  type AppointmentRequest,
  AppointmentRequestStatus,
  TimePreference,
  parseDate,
  parseDateOptional,
} from '@vetplus/shared';
import { db } from './firebase';

export const requestsCol = () => collection(db, 'appointmentRequests');
export const requestDoc = (id: string) => doc(db, 'appointmentRequests', id);

/** Pet owner's own requests. Sorted client-side to avoid a composite index. */
export function petOwnerRequestsQuery(uid: string) {
  return query(requestsCol(), where('petOwnerId', '==', uid));
}

/** All requests for a clinic (staff). Single-field query; filter/sort client-side. */
export function clinicRequestsQuery(clinicId: string) {
  return query(requestsCol(), where('clinicId', '==', clinicId));
}

export function mapAppointmentRequest(id: string, d: DocumentData): AppointmentRequest {
  return {
    id,
    clinicId: (d.clinicId as string) ?? '',
    petOwnerId: (d.petOwnerId as string) ?? '',
    petOwnerName: (d.petOwnerName as string) ?? '',
    petId: (d.petId as string) ?? '',
    petName: (d.petName as string) ?? '',
    petSpecies: (d.petSpecies as string | null) ?? null,
    preferredDateStart: parseDate(d.preferredDateStart),
    preferredDateEnd: parseDate(d.preferredDateEnd),
    timePreference: (d.timePreference as TimePreference) ?? TimePreference.anyTime,
    reason: (d.reason as string) ?? '',
    notes: (d.notes as string | null) ?? null,
    status: (d.status as AppointmentRequestStatus) ?? AppointmentRequestStatus.pending,
    handledBy: (d.handledBy as string | null) ?? null,
    handledByName: (d.handledByName as string | null) ?? null,
    handledAt: parseDateOptional(d.handledAt) ?? null,
    responseMessage: (d.responseMessage as string | null) ?? null,
    linkedChatRoomId: (d.linkedChatRoomId as string | null) ?? null,
    createdAt: parseDate(d.createdAt),
    updatedAt: parseDate(d.updatedAt),
  };
}

export interface NewAppointmentRequest {
  clinicId: string;
  petOwnerId: string;
  petOwnerName: string;
  petId: string;
  petName: string;
  petSpecies?: string | null;
  preferredDateStart: Date;
  preferredDateEnd: Date;
  timePreference: TimePreference;
  reason: string;
  notes?: string | null;
}

export async function createRequest(r: NewAppointmentRequest): Promise<string> {
  const now = Date.now();
  const data: DocumentData = {
    clinicId: r.clinicId,
    petOwnerId: r.petOwnerId,
    petOwnerName: r.petOwnerName,
    petId: r.petId,
    petName: r.petName,
    petSpecies: r.petSpecies ?? null,
    preferredDateStart: r.preferredDateStart.getTime(),
    preferredDateEnd: r.preferredDateEnd.getTime(),
    timePreference: r.timePreference,
    reason: r.reason,
    notes: r.notes ?? null,
    status: AppointmentRequestStatus.pending,
    handledBy: null,
    handledByName: null,
    handledAt: null,
    responseMessage: null,
    linkedChatRoomId: null,
    createdAt: now,
    updatedAt: now,
  };
  const ref = await addDoc(requestsCol(), data);
  return ref.id;
}

/** Receptionist/staff confirms a request (booked externally). */
export async function confirmRequest(args: {
  requestId: string;
  handledBy: string;
  handledByName: string;
  message?: string | null;
}): Promise<void> {
  const now = Date.now();
  await updateDoc(requestDoc(args.requestId), {
    status: AppointmentRequestStatus.confirmed,
    handledBy: args.handledBy,
    handledByName: args.handledByName,
    handledAt: now,
    responseMessage: args.message ?? null,
    updatedAt: now,
  });
}

/** Receptionist/staff denies a request (reason required, like mobile). */
export async function denyRequest(args: {
  requestId: string;
  handledBy: string;
  handledByName: string;
  message: string;
}): Promise<void> {
  const now = Date.now();
  await updateDoc(requestDoc(args.requestId), {
    status: AppointmentRequestStatus.denied,
    handledBy: args.handledBy,
    handledByName: args.handledByName,
    handledAt: now,
    responseMessage: args.message,
    updatedAt: now,
  });
}

/** Link a chat room to a request (set when staff opens a chat from a request). */
export async function linkChatRoom(requestId: string, chatRoomId: string): Promise<void> {
  await updateDoc(requestDoc(requestId), {
    linkedChatRoomId: chatRoomId,
    updatedAt: Date.now(),
  });
}

/**
 * Cancel (delete) a pending request. Matches the mobile transaction: only
 * pending requests can be cancelled, and the doc is deleted rather than kept.
 */
export async function cancelRequest(requestId: string): Promise<void> {
  await runTransaction(db, async (tx) => {
    const ref = requestDoc(requestId);
    const snap = await tx.get(ref);
    if (!snap.exists()) throw new Error('Request not found');
    const status = (snap.data().status as number) ?? 0;
    if (status !== AppointmentRequestStatus.pending) {
      throw new Error('Only pending requests can be cancelled');
    }
    tx.delete(ref);
  });
}
