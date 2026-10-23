// Calendar events: users/{uid}/events/{eventId}. Appointments the vet books
// carry bookedByVetId so her agenda can find them across clients.
// Interop: dates as millisecondsSinceEpoch, `type` as the EventType integer
// index. Recurring events are NOT expanded into occurrences — each event is a
// single dated document (the mobile app spawns a new doc when a recurring dose
// is completed).

import {
  collection,
  collectionGroup,
  doc,
  addDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  getDocs,
  query,
  orderBy,
  where,
  writeBatch,
  type DocumentData,
} from 'firebase/firestore';
import { EventType, parseDate, parseDateOptional } from '@vetplus/shared';
import { db } from './firebase';

interface EventCommon {
  id: string;
  title: string;
  description: string;
  dateTime: Date;
  petId?: string | null;
  userId: string;
  seriesId?: string | null;
  isRecurring: boolean;
  recurrencePattern?: string | null;
  recurrenceInterval?: number | null;
  endDate?: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface AppointmentEvent extends EventCommon {
  type: EventType.appointment;
  vetName?: string | null;
  location?: string | null;
  appointmentType?: string | null;
  isConfirmed: boolean;
  contactInfo?: string | null;
  appointmentRequestId?: string | null;
  bookedByVetId?: string | null;
  /** Shown on the vet's agenda without reading the client profile. */
  clientName?: string | null;
  petName?: string | null;
}

export interface MedicationEvent extends EventCommon {
  type: EventType.medication;
  medicationName: string;
  dosage: string;
  frequency: string;
  customIntervalMinutes?: number | null;
  isCompleted: boolean;
  lastTaken?: Date | null;
  nextDose?: Date | null;
  remainingDoses?: number | null;
  instructions?: string | null;
  requiresNotification: boolean;
}

export interface NoteEvent extends EventCommon {
  type: EventType.note;
  category?: string | null;
  priority: number;
  isCompleted: boolean;
  tags?: string[] | null;
  reminderDateTime?: Date | null;
}

export type CalendarEvent = AppointmentEvent | MedicationEvent | NoteEvent;

export const eventsCol = (uid: string) => collection(db, 'users', uid, 'events');
export const eventDoc = (uid: string, id: string) =>
  doc(db, 'users', uid, 'events', id);

export function eventsQuery(uid: string) {
  return query(eventsCol(uid), orderBy('dateTime'));
}

/** Every appointment a vet booked, across all her clients' calendars.
 *  Needs the collection-group index on events.bookedByVetId (firestore.indexes.json). */
export function vetAppointmentsQuery(vetId: string) {
  return query(collectionGroup(db, 'events'), where('bookedByVetId', '==', vetId));
}

export const appointmentTitle = (petName?: string | null): string =>
  petName?.trim() ? `Consulta — ${petName.trim()}` : 'Consulta';

export interface VetAppointmentInput {
  /** Existing event id to update; omit to create. */
  id?: string | null;
  clientId: string;
  clientName: string;
  petId: string | null;
  petName: string | null;
  vetId: string;
  vetName: string;
  title: string;
  description: string;
  location: string | null;
  dateTime: Date;
  appointmentRequestId?: string | null;
}

/**
 * Ref + data for a vet-booked appointment in the client's calendar. Write it
 * with `{ merge: true }`; on update createdAt is left untouched.
 */
export function vetAppointmentWrite(a: VetAppointmentInput) {
  const now = new Date();
  const ref = a.id ? eventDoc(a.clientId, a.id) : doc(eventsCol(a.clientId));
  const data = eventToJson({
    id: ref.id,
    type: EventType.appointment,
    title: a.title,
    description: a.description,
    dateTime: a.dateTime,
    petId: a.petId,
    userId: a.clientId,
    isRecurring: false,
    createdAt: now,
    updatedAt: now,
    vetName: a.vetName,
    location: a.location,
    isConfirmed: true,
    appointmentRequestId: a.appointmentRequestId ?? null,
    bookedByVetId: a.vetId,
    clientName: a.clientName,
    petName: a.petName,
  });
  if (a.id) delete data.createdAt;
  return { ref, data };
}

/** Vet books (or edits) an appointment straight into a client's calendar. */
export async function saveVetAppointment(a: VetAppointmentInput): Promise<void> {
  const { ref, data } = vetAppointmentWrite(a);
  await setDoc(ref, data, { merge: true });
}

/* ------------------------------ (de)serialize ------------------------------ */

function common(id: string, d: DocumentData): EventCommon {
  return {
    id,
    title: (d.title as string) ?? '',
    description: (d.description as string) ?? '',
    dateTime: parseDate(d.dateTime),
    petId: (d.petId as string | null) ?? null,
    userId: (d.userId as string) ?? '',
    seriesId: (d.seriesId as string | null) ?? null,
    isRecurring: Boolean(d.isRecurring),
    recurrencePattern: (d.recurrencePattern as string | null) ?? null,
    recurrenceInterval: (d.recurrenceInterval as number | null) ?? null,
    endDate: parseDateOptional(d.endDate) ?? null,
    createdAt: parseDate(d.createdAt),
    updatedAt: parseDate(d.updatedAt),
  };
}

export function mapEvent(id: string, d: DocumentData): CalendarEvent {
  const type = (d.type as EventType) ?? EventType.note;
  const base = common(id, d);
  switch (type) {
    case EventType.appointment:
      return {
        ...base,
        type: EventType.appointment,
        vetName: (d.vetName as string | null) ?? null,
        location: (d.location as string | null) ?? null,
        appointmentType: (d.appointmentType as string | null) ?? null,
        isConfirmed: Boolean(d.isConfirmed),
        contactInfo: (d.contactInfo as string | null) ?? null,
        appointmentRequestId: (d.appointmentRequestId as string | null) ?? null,
        bookedByVetId: (d.bookedByVetId as string | null) ?? null,
        clientName: (d.clientName as string | null) ?? null,
        petName: (d.petName as string | null) ?? null,
      };
    case EventType.medication:
      return {
        ...base,
        type: EventType.medication,
        medicationName: (d.medicationName as string) ?? '',
        dosage: (d.dosage as string) ?? '',
        frequency: (d.frequency as string) ?? 'daily',
        customIntervalMinutes: (d.customIntervalMinutes as number | null) ?? null,
        isCompleted: Boolean(d.isCompleted),
        lastTaken: parseDateOptional(d.lastTaken) ?? null,
        nextDose: parseDateOptional(d.nextDose) ?? null,
        remainingDoses: (d.remainingDoses as number | null) ?? null,
        instructions: (d.instructions as string | null) ?? null,
        requiresNotification: d.requiresNotification == null ? true : Boolean(d.requiresNotification),
      };
    case EventType.note:
    default:
      return {
        ...base,
        type: EventType.note,
        category: (d.category as string | null) ?? null,
        priority: typeof d.priority === 'number' ? d.priority : 3,
        isCompleted: Boolean(d.isCompleted),
        tags: Array.isArray(d.tags) ? (d.tags as string[]) : null,
        reminderDateTime: parseDateOptional(d.reminderDateTime) ?? null,
      };
  }
}

function commonToJson(e: EventCommon, type: EventType): DocumentData {
  return {
    title: e.title,
    description: e.description,
    dateTime: e.dateTime.getTime(),
    type,
    petId: e.petId ?? null,
    userId: e.userId,
    seriesId: e.seriesId ?? null,
    isRecurring: e.isRecurring,
    recurrencePattern: e.recurrencePattern ?? null,
    recurrenceInterval: e.recurrenceInterval ?? null,
    endDate: e.endDate ? e.endDate.getTime() : null,
    createdAt: e.createdAt.getTime(),
    updatedAt: e.updatedAt.getTime(),
  };
}

export function eventToJson(e: CalendarEvent): DocumentData {
  const base = commonToJson(e, e.type);
  switch (e.type) {
    case EventType.appointment:
      return {
        ...base,
        vetName: e.vetName ?? null,
        location: e.location ?? null,
        appointmentType: e.appointmentType ?? null,
        isConfirmed: e.isConfirmed,
        contactInfo: e.contactInfo ?? null,
        appointmentRequestId: e.appointmentRequestId ?? null,
        bookedByVetId: e.bookedByVetId ?? null,
        clientName: e.clientName ?? null,
        petName: e.petName ?? null,
      };
    case EventType.medication:
      return {
        ...base,
        medicationName: e.medicationName,
        dosage: e.dosage,
        frequency: e.frequency,
        customIntervalMinutes: e.customIntervalMinutes ?? null,
        isCompleted: e.isCompleted,
        lastTaken: e.lastTaken ? e.lastTaken.getTime() : null,
        nextDose: e.nextDose ? e.nextDose.getTime() : null,
        remainingDoses: e.remainingDoses ?? null,
        instructions: e.instructions ?? null,
        requiresNotification: e.requiresNotification,
      };
    case EventType.note:
      return {
        ...base,
        category: e.category ?? null,
        priority: e.priority,
        isCompleted: e.isCompleted,
        tags: e.tags ?? null,
        reminderDateTime: e.reminderDateTime ? e.reminderDateTime.getTime() : null,
      };
  }
}

/* ----------------------------------- CRUD ---------------------------------- */

type DistributiveOmit<T, K extends keyof T> = T extends unknown ? Omit<T, K> : never;
export type NewEvent = DistributiveOmit<CalendarEvent, 'id'>;

export async function createEvent(uid: string, event: NewEvent): Promise<string> {
  const json = eventToJson({ ...event, id: '' } as CalendarEvent);
  const ref = await addDoc(eventsCol(uid), json);
  return ref.id;
}

export async function updateEvent(uid: string, event: CalendarEvent): Promise<void> {
  await updateDoc(eventDoc(uid, event.id), eventToJson(event));
}

export async function deleteEvent(uid: string, id: string): Promise<void> {
  await deleteDoc(eventDoc(uid, id));
}

export async function setEventCompleted(
  uid: string,
  id: string,
  completed: boolean,
): Promise<void> {
  await updateDoc(eventDoc(uid, id), {
    isCompleted: completed,
    updatedAt: Date.now(),
  });
}

/** Delete all events linked to a pet (used when deleting the pet). */
export async function deleteEventsForPet(uid: string, petId: string): Promise<void> {
  const snap = await getDocs(query(eventsCol(uid), where('petId', '==', petId)));
  if (snap.empty) return;
  const batch = writeBatch(db);
  snap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
}
