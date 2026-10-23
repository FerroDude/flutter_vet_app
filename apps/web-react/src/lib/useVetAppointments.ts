import { useMemo } from 'react';
import { EventType } from '@vetplus/shared';
import { useCollection } from './useFirestore';
import { mapEvent, vetAppointmentsQuery, type AppointmentEvent } from './eventService';

/** Live list of a vet's booked appointments, oldest first. */
export function useVetAppointments(vetId: string) {
  const q = useMemo(() => (vetId ? vetAppointmentsQuery(vetId) : null), [vetId]);
  const { data, loading, error } = useCollection(q, mapEvent);
  const appointments = useMemo(
    () =>
      data
        .filter((e): e is AppointmentEvent => e.type === EventType.appointment)
        .sort((a, b) => a.dateTime.getTime() - b.dateTime.getTime()),
    [data],
  );
  return { appointments, loading, error };
}
