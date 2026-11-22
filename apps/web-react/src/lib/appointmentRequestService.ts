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
    vetId: (d.vetId as string | null) ?? null,
    clinicId: (d.clinicId as string | null) ?? null,
    requestedVetId: (d.requestedVetId as string | null) ?? null,
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

/** Requests by field (`petOwnerId` for a client), newest first. */
export function useRequests(field: 'petOwnerId', id: string) {
  const q = useMemo(() => (id ? query(requestsCol(), where(field, '==', id)) : null), [field, id]);
  const { data, loading } = useCollection(q, mapAppointmentRequest);
  const requests = useMemo(
    () => [...data].sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime()),
    [data],
  );
  return { requests, loading };
}

/**
 * Staff requests: mine (assigned to me) + the clinic pool (unassigned).
 */
export function useClinicRequests(clinicId: string, uid: string) {
  const mineQ = useMemo(
    () =>
      clinicId && uid
        ? query(requestsCol(), where('clinicId', '==', clinicId), where('vetId', '==', uid))
        : null,
    [clinicId, uid],
  );
  const poolQ = useMemo(
    () =>
      clinicId
        ? query(requestsCol(), where('clinicId', '==', clinicId), where('vetId', '==', null))
        : null,
    [clinicId],
  );
  const mine = useCollection(mineQ, mapAppointmentRequest);
  const pool = useCollection(poolQ, mapAppointmentRequest);
  return useMemo(
    () => ({
      mine: [...mine.data].sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime()),
      pool: [...pool.data].sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime()),
      loading: mine.loading || pool.loading,
    }),
    [mine.data, mine.loading, pool.data, pool.loading],
  );
}

export interface NewAppointmentRequest {
  clinicId: string;
  /** Chosen vet (directed request) or null for the pool ("any vet"). */
  vetId: string | null;
  vetName: string | null;
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
    requestedVetId: r.vetId,
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

function alreadyHandled(d: DocumentData, uid: string): Error | null {
  const name = (d.handledByName as string) || t('common.vet');
  if ((d.status ?? 0) !== AppointmentRequestStatus.pending) {
    return new Error(t('requests.alreadyHandled', { name }));
  }
  if (d.vetId && d.vetId !== uid) {
    return new Error(t('requests.alreadyHandled', { name }));
  }
  return null;
}

/**
 * Vet confirms: books the visit in the client's calendar and marks the
 * request, in one transaction. Claiming from the pool also assigns vetId.
 */
export async function confirmRequest(args: {
  request: AppointmentRequest;
  clinicId: string;
  vetId: string;
  vetName: string;
  dateTime: Date;
  message?: string | null;
}): Promise<void> {
  const r = args.request;
  // UI-only guard: confirmations stay inside the client's requested window.
  const windowError = requestWindowError(r, args.dateTime);
  if (windowError) throw new Error(windowError);
  const now = Date.now();
  await runTransaction(db, async (tx) => {
    const ref = requestDoc(r.id);
    const snap = await tx.get(ref);
    if (!snap.exists()) throw new Error(t('requests.gone'));
    const guard = alreadyHandled(snap.data(), args.vetId);
    if (guard) throw guard;
    const event = vetAppointmentWrite({
      id: r.calendarEventId,
      clientId: r.petOwnerId,
      clientName: r.petOwnerName,
      petId: r.petId,
      petName: r.petName,
      clinicId: args.clinicId,
      vetId: args.vetId,
      vetName: args.vetName,
      bookedByVetId: args.vetId,
      title: appointmentTitle(r.petName),
      description: r.reason,
      location: null,
      dateTime: args.dateTime,
      appointmentRequestId: r.id,
    });
    tx.set(event.ref, event.data, { merge: true });
    tx.update(ref, {
      status: AppointmentRequestStatus.confirmed,
      vetId: args.vetId,
      vetName: args.vetName,
      claimedAt: now,
      handledBy: args.vetId,
      handledByName: args.vetName,
      handledAt: now,
      responseMessage: args.message ?? null,
      calendarEventId: event.ref.id,
      bookedDateTime: args.dateTime.getTime(),
      updatedAt: now,
    });
  });
}

export async function denyRequest(args: {
  requestId: string;
  vetId: string;
  vetName: string;
  message: string;
}): Promise<void> {
  const now = Date.now();
  await runTransaction(db, async (tx) => {
    const ref = requestDoc(args.requestId);
    const snap = await tx.get(ref);
    if (!snap.exists()) throw new Error(t('requests.gone'));
    const guard = alreadyHandled(snap.data(), args.vetId);
    if (guard) throw guard;
    tx.update(ref, {
      status: AppointmentRequestStatus.denied,
      vetId: args.vetId,
      vetName: args.vetName,
      claimedAt: now,
      handledBy: args.vetId,
      handledByName: args.vetName,
      handledAt: now,
      responseMessage: args.message,
      updatedAt: now,
    });
  });
}

/** Give my pending request back to the clinic pool ("pass to clinic"). */
export async function releaseRequest(requestId: string): Promise<void> {
  await updateDoc(requestDoc(requestId), {
    vetId: null,
    releasedAt: Date.now(),
    updatedAt: Date.now(),
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
