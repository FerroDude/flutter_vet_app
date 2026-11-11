// Medication data layer (pet owner). Mirrors
// apps/mobile-flutter/lib/repositories/medication_repository.dart.
//
// Storage: users/{uid}/pets/{petId}/medications/{medId}
// Interop: dates as millisecondsSinceEpoch, enums as integer indices,
// doseTimes as {hour, minute}, doseHistory as an array of dose-log maps —
// exactly matching the Dart Medication.toJson().

import {
  collection,
  doc,
  addDoc,
  updateDoc,
  deleteDoc,
  query,
  orderBy,
  runTransaction,
  type DocumentData,
} from 'firebase/firestore';
import {
  type Medication,
  type DoseLog,
  type TimeOfDay,
  MedicationFrequency,
  MedicationStatus,
  applyDoseSlotChanges,
  parseDate,
  parseDateOptional,
} from '@vetplus/shared';
import { db } from './firebase';
import { t } from '@/i18n';

export const medsCol = (uid: string, petId: string) =>
  collection(db, 'users', uid, 'pets', petId, 'medications');

export const medDoc = (uid: string, petId: string, medId: string) =>
  doc(db, 'users', uid, 'pets', petId, 'medications', medId);

export function medsQuery(uid: string, petId: string) {
  return query(medsCol(uid, petId), orderBy('status'));
}

/* ------------------------------ (de)serialize ------------------------------ */

function parseDoseTimes(raw: unknown): TimeOfDay[] {
  const out: TimeOfDay[] = [];
  if (Array.isArray(raw)) {
    for (const t of raw) {
      if (t && typeof t === 'object' && 'hour' in t) {
        out.push({ hour: Number((t as TimeOfDay).hour ?? 8), minute: Number((t as TimeOfDay).minute ?? 0) });
      } else if (typeof t === 'number') {
        out.push({ hour: Math.floor(t / 60), minute: t % 60 }); // legacy minutes-of-day
      }
    }
  }
  return out.length > 0 ? out : [{ hour: 8, minute: 0 }];
}

function parseDoseHistory(raw: unknown): DoseLog[] {
  if (!Array.isArray(raw)) return [];
  return raw.map((d) => {
    const o = d as DocumentData;
    return {
      id: (o.id as string) ?? crypto.randomUUID(),
      scheduledTime: parseDate(o.scheduledTime),
      takenAt: parseDateOptional(o.takenAt) ?? null,
      skipped: Boolean(o.skipped),
      notes: (o.notes as string | null) ?? null,
    };
  });
}

export function mapMedication(id: string, data: DocumentData): Medication {
  return {
    id,
    petId: (data.petId as string) ?? '',
    ownerId: (data.ownerId as string) ?? '',
    name: (data.name as string) ?? '',
    dosage: (data.dosage as string) ?? '',
    instructions: (data.instructions as string | null) ?? null,
    frequency: (data.frequency as MedicationFrequency) ?? MedicationFrequency.daily,
    doseTimes: parseDoseTimes(data.doseTimes),
    startDate: parseDate(data.startDate),
    endDate: parseDateOptional(data.endDate) ?? null,
    totalDays: (data.totalDays as number | null) ?? null,
    status: (data.status as MedicationStatus) ?? MedicationStatus.active,
    trackDoses: Boolean(data.trackDoses),
    doseHistory: parseDoseHistory(data.doseHistory),
    remindersEnabled: data.remindersEnabled == null ? true : Boolean(data.remindersEnabled),
    createdAt: parseDate(data.createdAt),
    updatedAt: parseDate(data.updatedAt),
    prescribedByVetId: (data.prescribedByVetId as string | null) ?? null,
    prescribedByVetName: (data.prescribedByVetName as string | null) ?? null,
  };
}

function doseLogToJson(d: DoseLog): DocumentData {
  return {
    id: d.id,
    scheduledTime: d.scheduledTime.getTime(),
    takenAt: d.takenAt ? d.takenAt.getTime() : null,
    skipped: d.skipped,
    notes: d.notes ?? null,
  };
}

function medToJson(m: Omit<Medication, 'id'>): DocumentData {
  return {
    petId: m.petId,
    ownerId: m.ownerId,
    name: m.name,
    dosage: m.dosage,
    instructions: m.instructions ?? null,
    frequency: m.frequency,
    doseTimes: m.doseTimes.map((t) => ({ hour: t.hour, minute: t.minute })),
    startDate: m.startDate.getTime(),
    endDate: m.endDate ? m.endDate.getTime() : null,
    totalDays: m.totalDays ?? null,
    status: m.status,
    trackDoses: m.trackDoses,
    doseHistory: m.doseHistory.map(doseLogToJson),
    remindersEnabled: m.remindersEnabled,
    createdAt: m.createdAt.getTime(),
    updatedAt: m.updatedAt.getTime(),
    prescribedByVetId: m.prescribedByVetId ?? null,
    prescribedByVetName: m.prescribedByVetName ?? null,
  };
}

/* --------------------------------- inputs ---------------------------------- */

export interface MedicationInput {
  name: string;
  dosage: string;
  instructions?: string | null;
  frequency: MedicationFrequency;
  doseTimes: TimeOfDay[];
  startDate: Date;
  totalDays?: number | null;
  trackDoses: boolean;
  /** Past slots already given (picked in the form); logged at create time. */
  takenSlots?: Date[];
}

export async function createMedication(
  uid: string,
  petId: string,
  input: MedicationInput,
): Promise<string> {
  const now = new Date();
  const med: Omit<Medication, 'id'> = {
    petId,
    ownerId: uid,
    name: input.name.trim(),
    dosage: input.dosage.trim(),
    instructions: input.instructions?.trim() || null,
    frequency: input.frequency,
    doseTimes: input.doseTimes,
    startDate: input.startDate,
    endDate: null,
    totalDays: input.totalDays ?? null,
    status: MedicationStatus.active,
    trackDoses: input.trackDoses,
    doseHistory: (input.takenSlots ?? []).map((at) => ({
      id: crypto.randomUUID(),
      scheduledTime: at,
      takenAt: at,
      skipped: false,
      notes: null,
    })),
    remindersEnabled: true,
    createdAt: now,
    updatedAt: now,
    prescribedByVetId: null,
    prescribedByVetName: null,
  };
  const ref = await addDoc(medsCol(uid, petId), medToJson(med));
  return ref.id;
}

export async function updateMedicationFields(
  uid: string,
  petId: string,
  medId: string,
  input: MedicationInput,
): Promise<void> {
  await updateDoc(medDoc(uid, petId, medId), {
    name: input.name.trim(),
    dosage: input.dosage.trim(),
    instructions: input.instructions?.trim() || null,
    frequency: input.frequency,
    doseTimes: input.doseTimes.map((t) => ({ hour: t.hour, minute: t.minute })),
    startDate: input.startDate.getTime(),
    totalDays: input.totalDays ?? null,
    trackDoses: input.trackDoses,
    updatedAt: Date.now(),
  });
}

export async function deleteMedication(
  uid: string,
  petId: string,
  medId: string,
): Promise<void> {
  await deleteDoc(medDoc(uid, petId, medId));
}

export async function setMedicationStatus(
  uid: string,
  petId: string,
  medId: string,
  status: MedicationStatus,
): Promise<void> {
  await updateDoc(medDoc(uid, petId, medId), {
    status,
    updatedAt: Date.now(),
  });
}

/* ------------------------------- dose logging ------------------------------ */

export async function logDoseTaken(
  uid: string,
  petId: string,
  medId: string,
  scheduledTime: Date,
  notes?: string,
): Promise<void> {
  const ref = medDoc(uid, petId, medId);
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists()) throw new Error(t('errors.medNotFound'));
    const med = mapMedication(snap.id, snap.data());
    const newLog: DoseLog = {
      id: crypto.randomUUID(),
      scheduledTime,
      takenAt: scheduledTime, // taken time = scheduled (supports logging past doses)
      skipped: false,
      notes: notes ?? null,
    };
    tx.update(ref, {
      doseHistory: [...med.doseHistory, newLog].map(doseLogToJson),
      updatedAt: Date.now(),
    });
  });
}

export async function undoLastDose(
  uid: string,
  petId: string,
  medId: string,
): Promise<boolean> {
  const ref = medDoc(uid, petId, medId);
  return runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists()) throw new Error(t('errors.medNotFound'));
    const med = mapMedication(snap.id, snap.data());

    let mostRecentIndex = -1;
    let mostRecent = -Infinity;
    med.doseHistory.forEach((d, i) => {
      if (d.takenAt != null && d.takenAt.getTime() > mostRecent) {
        mostRecent = d.takenAt.getTime();
        mostRecentIndex = i;
      }
    });
    if (mostRecentIndex === -1) return false;

    const next = med.doseHistory.filter((_, i) => i !== mostRecentIndex);
    tx.update(ref, {
      doseHistory: next.map(doseLogToJson),
      updatedAt: Date.now(),
    });
    return true;
  });
}

/**
 * Tick/untick past dose slots in bulk (the "Histórico de doses" editor).
 * `changes` carries the diff only; matching uses the full slot set so it
 * mirrors what the dialog showed (see applyDoseSlotChanges).
 */
export async function setDoseSlots(
  uid: string,
  petId: string,
  medId: string,
  changes: { at: Date; taken: boolean }[],
): Promise<void> {
  if (changes.length === 0) return;
  const ref = medDoc(uid, petId, medId);
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists()) throw new Error(t('errors.medNotFound'));
    const med = mapMedication(snap.id, snap.data());
    tx.update(ref, {
      doseHistory: applyDoseSlotChanges(med, changes).map(doseLogToJson),
      updatedAt: Date.now(),
    });
  });
}
