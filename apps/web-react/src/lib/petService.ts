// Pet + symptom data layer for the pet owner.
//
// IMPORTANT — interop with mobile: the real pet documents do NOT match the
// `Pet` model in packages/shared (that model is the vet-facing/stale shape).
// The mobile pet form (lib/pages/petOwners/pet_form_page.dart) and list
// (pets_page.dart) read/write this shape, so we mirror it exactly:
//   name, species, breed, weight(string), color, microchip, veterinarian,
//   medicalNotes, emergencyContact, gender('Male'|'Female'|'Unknown'),
//   dateOfBirth(Timestamp|null), order(int), createdAt/updatedAt(Timestamp).
// Symptoms store `timestamp` as a Firestore Timestamp (pet_service.dart), so we
// write Timestamps too — writing ms numbers would break mobile's range queries.

import {
  collection,
  doc,
  addDoc,
  updateDoc,
  deleteDoc,
  getDocs,
  query,
  orderBy,
  serverTimestamp,
  Timestamp,
  type DocumentData,
} from 'firebase/firestore';
import {
  type SymptomType,
  type PetSymptom,
  parseDate,
  parseDateOptional,
} from '@vetplus/shared';
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { db, storage } from './firebase';
import { deleteEventsForPet } from './eventService';

export type PetGender = 'Male' | 'Female' | 'Unknown';

export interface PetFields {
  name: string;
  species: string;
  breed: string;
  weight: string;
  color: string;
  microchip: string;
  veterinarian: string;
  medicalNotes: string;
  emergencyContact: string;
  gender: PetGender;
  dateOfBirth: Date | null;
}

export interface Pet extends PetFields {
  id: string;
  order: number;
  photoUrl: string | null;
}

export const petsCol = (uid: string) => collection(db, 'users', uid, 'pets');
export const petDoc = (uid: string, petId: string) =>
  doc(db, 'users', uid, 'pets', petId);

export function petsQuery(uid: string) {
  return query(petsCol(uid), orderBy('order'));
}

export function mapPet(id: string, data: DocumentData): Pet {
  return {
    id,
    name: (data.name as string) ?? '',
    species: (data.species as string) ?? '',
    breed: (data.breed as string) ?? '',
    weight: (data.weight as string) ?? '',
    color: (data.color as string) ?? '',
    microchip: (data.microchip as string) ?? '',
    veterinarian: (data.veterinarian as string) ?? '',
    medicalNotes: (data.medicalNotes as string) ?? '',
    emergencyContact: (data.emergencyContact as string) ?? '',
    gender: (data.gender as PetGender) ?? 'Unknown',
    dateOfBirth: parseDateOptional(data.dateOfBirth) ?? null,
    order: typeof data.order === 'number' ? data.order : 0,
    photoUrl:
      (data.photoUrl as string | null) ?? (data.imageUrl as string | null) ?? null,
  };
}

function fieldsToDoc(fields: PetFields): DocumentData {
  return {
    name: fields.name.trim(),
    species: fields.species.trim(),
    breed: fields.breed.trim(),
    weight: fields.weight.trim(),
    color: fields.color.trim(),
    microchip: fields.microchip.trim(),
    veterinarian: fields.veterinarian.trim(),
    medicalNotes: fields.medicalNotes.trim(),
    emergencyContact: fields.emergencyContact.trim(),
    gender: fields.gender,
    dateOfBirth: fields.dateOfBirth ? Timestamp.fromDate(fields.dateOfBirth) : null,
    updatedAt: serverTimestamp(),
  };
}

export async function addPet(uid: string, fields: PetFields): Promise<string> {
  const existing = await getDocs(petsCol(uid));
  const ref = await addDoc(petsCol(uid), {
    ...fieldsToDoc(fields),
    order: existing.size,
    createdAt: serverTimestamp(),
  });
  return ref.id;
}

export async function updatePet(
  uid: string,
  petId: string,
  fields: PetFields,
): Promise<void> {
  await updateDoc(petDoc(uid, petId), fieldsToDoc(fields));
}

const MAX_PHOTO_BYTES = 5 * 1024 * 1024;

/** Upload a (already cropped) pet photo blob to Storage, then point the doc at it. */
export async function uploadPetPhoto(uid: string, petId: string, photo: Blob): Promise<string> {
  if (!photo.type.startsWith('image/')) throw new Error('Escolha uma imagem.');
  if (photo.size >= MAX_PHOTO_BYTES) throw new Error('A imagem é demasiado grande.');

  const storageRef = ref(storage, `pets/${uid}/${petId}/photo_${Date.now()}.jpg`);
  await uploadBytes(storageRef, photo, { contentType: 'image/jpeg' });
  const url = await getDownloadURL(storageRef);
  await updateDoc(petDoc(uid, petId), { photoUrl: url, imageUrl: null, updatedAt: serverTimestamp() });
  return url;
}

export async function removePetPhoto(uid: string, petId: string): Promise<void> {
  await updateDoc(petDoc(uid, petId), { photoUrl: null, imageUrl: null, updatedAt: serverTimestamp() });
}

export async function deletePet(uid: string, petId: string): Promise<void> {
  // Mirror mobile: remove calendar events linked to this pet, then the pet.
  // (Medications/symptoms live in subcollections and become inaccessible once
  // the pet doc is gone, matching the Flutter behavior.)
  await deleteEventsForPet(uid, petId);
  await deleteDoc(petDoc(uid, petId));
}

/** Human-readable age from a birth date (mirrors dashboard_page getAge). */
export function petAgeLabel(dob: Date | null): string {
  if (!dob) return 'Idade desconhecida';
  const now = new Date();
  const days = Math.floor((now.getTime() - dob.getTime()) / 86_400_000);
  const years = Math.floor(days / 365);
  const months = Math.floor((days % 365) / 30);
  if (years > 0) return `${years} ${years === 1 ? 'ano' : 'anos'}`;
  if (months > 0) return `${months} ${months === 1 ? 'mês' : 'meses'}`;
  return 'Menos de um mês';
}

/* --------------------------------- Symptoms --------------------------------- */

export const symptomsCol = (uid: string, petId: string) =>
  collection(db, 'users', uid, 'pets', petId, 'symptoms');

export function symptomsQuery(uid: string, petId: string) {
  return query(symptomsCol(uid, petId), orderBy('timestamp', 'desc'));
}

export function mapSymptom(
  ownerId: string,
  petId: string,
  id: string,
  data: DocumentData,
): PetSymptom {
  return {
    id,
    ownerId,
    petId,
    type: ((data.type as string) ?? 'other') as SymptomType,
    timestamp: parseDate(data.timestamp),
    note: (data.note as string | null) ?? null,
    createdAt: parseDate(data.createdAt),
  };
}

export async function addSymptom(
  uid: string,
  petId: string,
  type: SymptomType,
  at: Date,
  note?: string,
): Promise<string> {
  const ref = await addDoc(symptomsCol(uid, petId), {
    ownerId: uid,
    petId,
    type,
    timestamp: Timestamp.fromDate(at),
    note: note?.trim() ? note.trim() : null,
    createdAt: serverTimestamp(),
  });
  return ref.id;
}

export async function deleteSymptom(
  uid: string,
  petId: string,
  symptomId: string,
): Promise<void> {
  await deleteDoc(doc(db, 'users', uid, 'pets', petId, 'symptoms', symptomId));
}
