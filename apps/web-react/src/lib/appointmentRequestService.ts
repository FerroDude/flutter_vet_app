// Appointment requests: top-level appointmentRequests/{id}. A client asks
// their vet for a visit; the vet confirms (booking it into the client's
// calendar) or denies with a reason. Dates as ms, enums as integers.

import { useMemo } from 'react';
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
  TimePreference,
  parseDate,
  parseDateOptional,
} from '@vetplus/shared';
import { db } from './firebase';
import { useCollection } from './useFirestore';
import { appointmentTitle, vetAppointmentWrite } from './eventService';
import { requestWindowError } from './requestWindow';
import { t } from '@/i18n';

const requestsCol = () => collection(db, 'appointmentRequests');
const requestDoc = (id: string) => doc(db, 'appointmentRequests', id);

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

/** Requests by field (`petOwnerId` for a client, `vetId` for a vet), newest first. */
export function useRequests(field: 'petOwnerId' | 'vetId', id: string) {
  const q = useMemo(() => (id ? query(requestsCol(), where(field, '==', id)) : null), [field, id]);
  const { data, loading } = useCollection(q, mapAppointmentRequest);
  const requests = useMemo(
    () => [...data].sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime()),
    [data],
  );
  return { requests, loading };
}

/** Pending requests for a vet, oldest first (the order she should handle them). */
export function useVetPendingRequests(vetId: string): AppointmentRequest[] {
  const { requests } = useRequests('vetId', vetId);
  return useMemo(
    () => requests.filter((r) => r.status === AppointmentRequestStatus.pending).reverse(),
    [requests],
  );
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

export async function createRequest(r: NewAppointmentRequest): Promise<void> {
  const now = Date.now();
  await addDoc(requestsCol(), {
    ...r,
    petSpecies: r.petSpecies ?? null,
    preferredDateStart: r.preferredDateStart.getTime(),
    preferredDateEnd: r.preferredDateEnd.getTime(),
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
  });
}

/** Vet confirms: books the visit in the client's calendar and marks the request, in one batch. */
export async function confirmRequest(args: {
  request: AppointmentRequest;
  vetId: string;
  vetName: string;
  dateTime: Date;
  message?: string | null;
}): Promise<void> {
  const r = args.request;
  // UI-only guard: confirmations stay inside the client's requested window.
  const windowError = requestWindowError(r, args.dateTime);
  if (windowError) throw new Error(windowError);
  const event = vetAppointmentWrite({
    id: r.calendarEventId,
    clientId: r.petOwnerId,
    clientName: r.petOwnerName,
    petId: r.petId,
    petName: r.petName,
    vetId: args.vetId,
    vetName: args.vetName,
    title: appointmentTitle(r.petName),
    description: r.reason,
    location: null,
    dateTime: args.dateTime,
    appointmentRequestId: r.id,
  });
  const now = Date.now();
  const batch = writeBatch(db);
  batch.set(event.ref, event.data, { merge: true });
  batch.update(requestDoc(r.id), {
    status: AppointmentRequestStatus.confirmed,
    handledBy: args.vetId,
    handledByName: args.vetName,
    handledAt: now,
    responseMessage: args.message ?? null,
    calendarEventId: event.ref.id,
    bookedDateTime: args.dateTime.getTime(),
    updatedAt: now,
  });
  await batch.commit();
}

export async function denyRequest(args: {
  requestId: string;
  vetId: string;
  vetName: string;
  message: string;
}): Promise<void> {
  const now = Date.now();
  await updateDoc(requestDoc(args.requestId), {
    status: AppointmentRequestStatus.denied,
    handledBy: args.vetId,
    handledByName: args.vetName,
    handledAt: now,
    responseMessage: args.message,
    updatedAt: now,
  });
}

/** Client cancels (deletes) a request that is still pending. */
export async function cancelRequest(requestId: string): Promise<void> {
  await runTransaction(db, async (tx) => {
    const ref = requestDoc(requestId);
    const snap = await tx.get(ref);
    if (!snap.exists()) throw new Error(t('requests.gone'));
    if ((snap.data().status ?? 0) !== AppointmentRequestStatus.pending) {
      throw new Error(t('requests.onlyPending'));
    }
    tx.delete(ref);
  });
}
