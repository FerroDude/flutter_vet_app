// Public pet tags (QR codes): top-level petTags/{petId} with only the fields a
// stranger needs — no medical data, no email. Read is public by id; writes are
// owner-only via the rules.

import { doc, getDoc, setDoc, updateDoc, deleteDoc, serverTimestamp, type DocumentData } from 'firebase/firestore';
import { db } from './firebase';
import { petDoc, mapPet, type Pet } from './petService';

export interface PetTag {
  petId: string;
  ownerId: string;
  petName: string;
  species: string;
  breed: string;
  photoUrl: string | null;
  contactName: string;
  contactPhone: string | null;
  showPhone: boolean;
}

const tagDoc = (petId: string) => doc(db, 'petTags', petId);

function mapPetTag(id: string, d: DocumentData): PetTag {
  return {
    petId: (d.petId as string) ?? id,
    ownerId: (d.ownerId as string) ?? '',
    petName: (d.petName as string) ?? '',
    species: (d.species as string) ?? '',
    breed: (d.breed as string) ?? '',
    photoUrl: (d.photoUrl as string | null) ?? null,
    contactName: (d.contactName as string) ?? '',
    contactPhone: (d.contactPhone as string | null) ?? null,
    showPhone: Boolean(d.showPhone),
  };
}

export async function getPetTag(petId: string): Promise<PetTag | null> {
  const snap = await getDoc(tagDoc(petId));
  return snap.exists() ? mapPetTag(snap.id, snap.data()) : null;
}

/** Create/refresh the owner's public tag for a pet. */
export async function syncPetTag(
  ownerId: string,
  pet: Pet,
  owner: { displayName: string; phone: string },
  showPhone: boolean,
): Promise<void> {
  await setDoc(tagDoc(pet.id), {
    ownerId,
    petId: pet.id,
    petName: pet.name,
    species: pet.species,
    breed: pet.breed,
    photoUrl: pet.photoUrl ?? null,
    contactName: owner.displayName,
    contactPhone: showPhone && owner.phone ? owner.phone : null,
    showPhone,
    updatedAt: serverTimestamp(),
  });
}

/** After a pet edit/photo change: refresh the tag's public pet fields if the
 *  tag exists. Owner-side only; silently ignored otherwise. */
export async function refreshPetTag(ownerId: string, petId: string): Promise<void> {
  try {
    const snap = await getDoc(petDoc(ownerId, petId));
    if (!snap.exists()) return;
    const pet = mapPet(snap.id, snap.data());
    await updateDoc(tagDoc(petId), {
      petName: pet.name,
      species: pet.species,
      breed: pet.breed,
      photoUrl: pet.photoUrl ?? null,
      updatedAt: serverTimestamp(),
    });
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
