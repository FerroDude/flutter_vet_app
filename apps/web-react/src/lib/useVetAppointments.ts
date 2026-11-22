import { useMemo } from 'react';
import { EventType } from '@vetplus/shared';
import { useCollection } from './useFirestore';
import { mapEvent, clinicAppointmentsQuery, type AppointmentEvent } from './eventService';

/** Live list of the clinic's booked appointments, oldest first. */
export function useVetAppointments(clinicId: string) {
  const q = useMemo(() => (clinicId ? clinicAppointmentsQuery(clinicId) : null), [clinicId]);
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
