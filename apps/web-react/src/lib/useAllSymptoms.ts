// Aggregates symptoms across all of a user's pets (pets listener + per-pet
// symptoms listener). Mirrors the mobile calendar's symptomsByDayForUser.

import { useEffect, useState } from 'react';
import { onSnapshot } from 'firebase/firestore';
import { type PetSymptom } from '@vetplus/shared';
import { petsQuery } from './petService';
import { symptomsCol, mapSymptom } from './petService';

export function useAllSymptoms(uid: string): PetSymptom[] {
  const [symptoms, setSymptoms] = useState<PetSymptom[]>([]);

  useEffect(() => {
    if (!uid) {
      setSymptoms([]);
      return;
    }

    const byPet = new Map<string, PetSymptom[]>();
    const unsubs = new Map<string, () => void>();
    const emit = () =>
      setSymptoms(
        Array.from(byPet.values())
          .flat()
          .sort((a, b) => b.timestamp.getTime() - a.timestamp.getTime()),
      );

    const unsubPets = onSnapshot(petsQuery(uid), (snap) => {
      const ids = new Set(snap.docs.map((d) => d.id));
      for (const [pid, unsub] of unsubs) {
        if (!ids.has(pid)) {
          unsub();
          unsubs.delete(pid);
          byPet.delete(pid);
        }
      }
      snap.docs.forEach((petDoc) => {
        const pid = petDoc.id;
        if (unsubs.has(pid)) return;
        const unsub = onSnapshot(symptomsCol(uid, pid), (symSnap) => {
          byPet.set(
            pid,
            symSnap.docs.map((s) => mapSymptom(uid, pid, s.id, s.data())),
          );
          emit();
        });
        unsubs.set(pid, unsub);
      });
      emit();
    });

    return () => {
      unsubPets();
      unsubs.forEach((u) => u());
    };
  }, [uid]);

  return symptoms;
}
