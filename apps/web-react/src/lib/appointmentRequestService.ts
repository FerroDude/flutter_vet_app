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
  writeBatch,
  query,
  where,
  type DocumentData,
} from 'firebase/firestore';
import {
  type AppointmentRequest,
  AppointmentRequestStatus,
  EventType,
  TimePreference,
  bookAppointmentFromConfirm,
  parseDate,
  parseDateOptional,
} from '@vetplus/shared';
import { db } from './firebase';
import {
  eventDoc,
  eventToJson,
  eventsCol,
  getEvent,
  type AppointmentEvent,
} from './eventService';

export const requestsCol = () => collection(db, 'appointmentRequests');
export const requestDoc = (id: string) => doc(db, 'appointmentRequests', id);

/** Pet owner's own requests. Sorted client-side to avoid a composite index. */
export function petOwnerRequestsQuery(uid: string) {
  return query(requestsCol(), where('petOwnerId', '==', uid));
}

/** Requests addressed to one vet. Single-field query; filter/sort client-side. */
export function vetRequestsQuery(vetId: string) {
  return query(requestsCol(), where('vetId', '==', vetId));
}

/** @deprecated Clinic queue. Kept so old staff screens compile until they are removed. */
export function clinicRequestsQuery(clinicId: string) {
  return query(requestsCol(), where('clinicId', '==', clinicId));
}

export function mapAppointmentRequest(id: string, d: DocumentData): AppointmentRequest {
  return {
    id,
    vetId: (d.vetId as string) ?? '',
    clinicId: (d.clinicId as string | null) ?? null,
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
    calendarEventId: (d.calendarEventId as string | null) ?? null,
    bookedDateTime: parseDateOptional(d.bookedDateTime) ?? null,
    createdAt: parseDate(d.createdAt),
    updatedAt: parseDate(d.updatedAt),
  };
}

export interface NewAppointmentRequest {
  vetId: string;
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
    vetId: r.vetId,
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
    calendarEventId: null,
    bookedDateTime: null,
    createdAt: now,
    updatedAt: now,
  };
  const ref = await addDoc(requestsCol(), data);
  return ref.id;
}

/** Vet confirms a request and writes or updates the client calendar event. */
export async function confirmRequest(args: {
  request: AppointmentRequest;
  handledBy: string;
  handledByName: string;
  message?: string | null;
  dateTime: Date;
}): Promise<void> {
  const now = new Date();
  let existingCreatedAt: Date | null = null;
  const existingId = args.request.calendarEventId ?? null;
  if (existingId) {
    const existing = await getEvent(args.request.petOwnerId, existingId);
    existingCreatedAt = existing?.createdAt ?? null;
  }
  const booked = bookAppointmentFromConfirm({
    requestId: args.request.id,
    clientId: args.request.petOwnerId,
    petId: args.request.petId,
    petName: args.request.petName,
    reason: args.request.reason,
    dateTime: args.dateTime,
    vetId: args.handledBy,
    vetName: args.handledByName,
    now,
    existingEventId: existingId,
    existingCreatedAt,
  });
  const eventRef = booked.eventId
    ? eventDoc(args.request.petOwnerId, booked.eventId)
    : doc(eventsCol(args.request.petOwnerId));
  const event: AppointmentEvent = {
    id: eventRef.id,
    title: booked.title,
    description: booked.description,
    dateTime: booked.dateTime,
    type: EventType.appointment,
    petId: booked.petId,
    userId: booked.userId,
    isRecurring: false,
    createdAt: booked.createdAt,
    updatedAt: booked.updatedAt,
    vetName: booked.vetName,
    isConfirmed: true,
    appointmentRequestId: booked.appointmentRequestId,
    bookedByVetId: booked.bookedByVetId,
  };
  // One batch: the client never sees an event while the request still looks pending.
  const batch = writeBatch(db);
  batch.set(eventRef, eventToJson(event), { merge: true });
  batch.update(requestDoc(args.request.id), {
    status: AppointmentRequestStatus.confirmed,
    handledBy: args.handledBy,
    handledByName: args.handledByName,
    handledAt: now.getTime(),
    responseMessage: args.message ?? null,
    calendarEventId: eventRef.id,
    bookedDateTime: args.dateTime.getTime(),
    updatedAt: now.getTime(),
  });
  await batch.commit();
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
