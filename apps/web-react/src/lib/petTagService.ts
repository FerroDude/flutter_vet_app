// Public pet tags (QR codes): top-level petTags/{petId} with only the fields a
// stranger needs — no medical data, no email. Read is public by id; writes are
// owner-only via the rules. petTags/{petId}/foundReports/* are "found" alerts
// anyone can send the owner.

import { useMemo } from 'react';
import {
  collection,
  collectionGroup,
  addDoc,
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  query,
  where,
  serverTimestamp,
  type DocumentData,
} from 'firebase/firestore';
import { db } from './firebase';
import { useCollection } from './useFirestore';
import { petDoc, mapPet, type Pet } from './petService';
import { parseDateOptional } from '@vetplus/shared';

export { PHONE_RE, EMAIL_RE, isValidContact } from './contact';

export interface PetTag {
  petId: string;
  ownerId: string;
  petName: string;
  species: string;
  breed: string;
  microchip: string;
  photoUrl: string | null;
  contactName: string | null;
  contactPhone: string | null;
  showContact: boolean;
}

export interface FoundReport {
  id: string;
  ownerId: string;
  petId: string;
  petName: string;
  finderName: string;
  finderContact: string;
  message: string;
  resolved: boolean;
  createdAt: Date | null;
}

const tagDoc = (petId: string) => doc(db, 'petTags', petId);
const reportsCol = (petId: string) => collection(db, 'petTags', petId, 'foundReports');

function mapPetTag(id: string, d: DocumentData): PetTag {
  return {
    petId: (d.petId as string) ?? id,
    ownerId: (d.ownerId as string) ?? '',
    petName: (d.petName as string) ?? '',
    species: (d.species as string) ?? '',
    breed: (d.breed as string) ?? '',
    microchip: (d.microchip as string) ?? '',
    photoUrl: (d.photoUrl as string | null) ?? null,
    contactName: (d.contactName as string | null) ?? null,
    contactPhone: (d.contactPhone as string | null) ?? null,
    showContact: d.showContact === true,
  };
}

export function mapFoundReport(id: string, d: DocumentData): FoundReport {
  return {
    id,
    ownerId: (d.ownerId as string) ?? '',
    petId: (d.petId as string) ?? '',
    petName: (d.petName as string) ?? '',
    finderName: (d.finderName as string) ?? '',
    finderContact: (d.finderContact as string) ?? '',
    message: (d.message as string) ?? '',
    resolved: d.resolved === true,
    createdAt: parseDateOptional(d.createdAt) ?? null,
  };
}

export async function getPetTag(petId: string): Promise<PetTag | null> {
  const snap = await getDoc(tagDoc(petId));
  return snap.exists() ? mapPetTag(snap.id, snap.data()) : null;
}

/** The public pet fields shared by owner and vet writes. */
const petFields = (pet: Pet) => ({
  petName: pet.name,
  species: pet.species,
  breed: pet.breed,
  microchip: pet.microchip ?? '',
  photoUrl: pet.photoUrl ?? null,
  updatedAt: serverTimestamp(),
});

/** Create/refresh the owner's public tag for a pet. Contact details are only
 *  written when showContact is on — the public page shows just the pet then. */
export async function syncPetTag(
  ownerId: string,
  pet: Pet,
  owner: { displayName: string; phone: string },
  showContact: boolean,
): Promise<void> {
  await setDoc(tagDoc(pet.id), {
    ownerId,
    petId: pet.id,
    ...petFields(pet),
    contactName: showContact ? owner.displayName : null,
    contactPhone: showContact && owner.phone ? owner.phone : null,
    showContact,
  });
}

/** Vet-side tag write when printing a QR the owner never created. Creates the
 *  tag with contact hidden (owner opts in later) or refreshes pet fields —
 *  rules forbid touching the owner's contact choice. */
export async function ensurePetTagAsVet(ownerId: string, pet: Pet): Promise<void> {
  if (!(await getPetTag(pet.id))) {
    await setDoc(tagDoc(pet.id), {
      ownerId,
      petId: pet.id,
      ...petFields(pet),
      contactName: null,
      contactPhone: null,
      showContact: false,
    });
    return;
  }
  await updateDoc(tagDoc(pet.id), petFields(pet));
}

/** After a pet edit/photo change: refresh the tag's public pet fields if the
 *  tag exists. Owner or the client's vet; silently ignored otherwise. */
export async function refreshPetTag(ownerId: string, petId: string): Promise<void> {
  try {
    const snap = await getDoc(petDoc(ownerId, petId));
    if (!snap.exists()) return;
    const pet = mapPet(snap.id, snap.data());
    await updateDoc(tagDoc(petId), petFields(pet));
  } catch {
    /* no tag or no permission */
  }
}

export async function deletePetTag(petId: string): Promise<void> {
  try {
    await deleteDoc(tagDoc(petId));
  } catch {
    /* no tag or no permission */
  }
}

/* ------------------------------ Found reports ------------------------------ */

/** Anonymous "I found this pet" alert on a public tag page. */
export async function sendFoundReport(
  tag: PetTag,
  report: { finderName: string; finderContact: string; message: string },
): Promise<void> {
  await addDoc(reportsCol(tag.petId), {
    ownerId: tag.ownerId,
    petId: tag.petId,
    petName: tag.petName,
    finderName: report.finderName.trim(),
    finderContact: report.finderContact.trim(),
    message: report.message.trim(),
    resolved: false,
    createdAt: serverTimestamp(),
  });
}

/** All of the owner's reports across their tags (sorted client-side). */
export function foundReportsQuery(uid: string) {
  return query(collectionGroup(db, 'foundReports'), where('ownerId', '==', uid));
}

/** Live list of the owner's found reports, newest first. */
export function useFoundReports(uid: string) {
  const q = useMemo(() => (uid ? foundReportsQuery(uid) : null), [uid]);
  const { data, loading, error } = useCollection(q, mapFoundReport);
  const reports = useMemo(
    () => [...data].sort((a, b) => (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0)),
    [data],
  );
  return { reports, loading, error };
}

export async function resolveFoundReport(petId: string, reportId: string): Promise<void> {
  await updateDoc(doc(reportsCol(petId), reportId), { resolved: true });
}
