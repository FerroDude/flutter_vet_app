import { useEffect, useRef, useState } from 'react';
import { getDocs } from 'firebase/firestore';
import type { UserProfile } from '@vetplus/shared';
import { petsQuery, mapPet, type Pet } from './petService';

export interface ClientPet {
  pet: Pet;
  owner: UserProfile;
}

/**
 * One-shot pet loads for the vet's client search — only while `enabled`
 * (search non-empty). Each client's pets are fetched once and cached for the
 * lifetime of the page; no live listeners. A client whose read fails is
 * skipped rather than breaking the search.
 */
export function useClientPets(
  clients: UserProfile[],
  enabled: boolean,
): { pets: ClientPet[]; loading: boolean } {
  const [pets, setPets] = useState<ClientPet[]>([]);
  const [loading, setLoading] = useState(false);
  const loaded = useRef(new Set<string>());

  useEffect(() => {
    if (!enabled) return;
    const missing = clients.filter((c) => !loaded.current.has(c.id));
    if (missing.length === 0) return;
    for (const c of missing) loaded.current.add(c.id);
    setLoading(true);
    void (async () => {
      const found: ClientPet[] = [];
      await Promise.all(
        missing.map(async (owner) => {
          try {
            const snap = await getDocs(petsQuery(owner.id));
            for (const d of snap.docs) found.push({ pet: mapPet(d.id, d.data()), owner });
          } catch {
            /* no access — skip this client */
          }
        }),
      );
      setPets((prev) => [...prev, ...found]);
      setLoading(false);
    })();
  }, [clients, enabled]);

  return { pets, loading };
}
