import { useMemo } from 'react';
import { UserType, type UserProfile } from '@vetplus/shared';
import { useCollection } from './useFirestore';
import { clientLabel, clientsQuery, mapClient } from './clientService';

/** A vet's clients, sorted by name. */
export function useClients(vetId: string) {
  const q = useMemo(() => (vetId ? clientsQuery(vetId) : null), [vetId]);
  const { data, loading, error } = useCollection<UserProfile>(q, mapClient);
  const clients = useMemo(
    () =>
      data
        .filter((c) => c.userType === UserType.petOwner)
        .sort((a, b) => clientLabel(a).localeCompare(clientLabel(b))),
    [data],
  );
  return { clients, loading, error };
}
