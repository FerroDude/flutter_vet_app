// Aggregates medications across all of a user's pets via one pets listener plus
// a per-pet medications listener. Mirrors the mobile dashboard's
// MedicationProvider.subscribeToPets without needing a collection-group index.

import { useEffect, useState } from 'react';
import { onSnapshot } from 'firebase/firestore';
import { type Medication } from '@vetplus/shared';
import { petsQuery } from './petService';
import { medsCol, mapMedication } from './medicationService';

export function useAllMedications(uid: string): Medication[] {
  const [meds, setMeds] = useState<Medication[]>([]);

  useEffect(() => {
    if (!uid) {
      setMeds([]);
      return;
    }

    const byPet = new Map<string, Medication[]>();
    const medUnsubs = new Map<string, () => void>();
    const emit = () => setMeds(Array.from(byPet.values()).flat());

    const unsubPets = onSnapshot(petsQuery(uid), (snap) => {
      const ids = new Set(snap.docs.map((d) => d.id));

      for (const [pid, unsub] of medUnsubs) {
        if (!ids.has(pid)) {
          unsub();
          medUnsubs.delete(pid);
          byPet.delete(pid);
        }
      }

      snap.docs.forEach((petDoc) => {
        const pid = petDoc.id;
        if (medUnsubs.has(pid)) return;
        const unsub = onSnapshot(medsCol(uid, pid), (medSnap) => {
          byPet.set(pid, medSnap.docs.map((m) => mapMedication(m.id, m.data())));
          emit();
        });
        medUnsubs.set(pid, unsub);
      });

      emit();
    });

    return () => {
      unsubPets();
      medUnsubs.forEach((u) => u());
    };
  }, [uid]);

  return meds;
}
