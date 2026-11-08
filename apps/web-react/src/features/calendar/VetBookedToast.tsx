import { useEffect, useMemo, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { toast } from 'sonner';
import { useAuth } from '@/auth/AuthProvider';
import { useCollection } from '@/lib/useFirestore';
import { eventsQuery, mapEvent, type AppointmentEvent, type CalendarEvent } from '@/lib/eventService';
import { diffVetBookings } from '@/lib/vetBookings';
import { dateTimeFmt } from '@/lib/format';
import { notifyOs } from '@/features/chat/incomingMessage';
import { t } from '@/i18n';

/** Always-on alert when the vet books an appointment for the client or moves
 *  one. Request-confirmed bookings are left to ConfirmedRequestToast.
 *  Baselines what exists on first load, then toasts each change. */
export function VetBookedToast() {
  const { firebaseUser } = useAuth();
  const navigate = useNavigate();
  const uid = firebaseUser?.uid ?? '';

  const q = useMemo(() => (uid ? eventsQuery(uid) : null), [uid]);
  const { data: events, loading } = useCollection<CalendarEvent>(q, mapEvent);
  const seen = useRef<Map<string, number> | null>(null);

  useEffect(() => {
    if (!uid || loading) return;
    const first = seen.current === null;
    const diff = diffVetBookings(seen.current ?? new Map(), events, Date.now());
    seen.current = diff.next;
    if (first || (diff.booked.length === 0 && diff.rescheduled.length === 0)) return;

    const describe = (e: AppointmentEvent) =>
      [e.petName, dateTimeFmt.format(e.dateTime), e.vetName].filter(Boolean).join(' · ');

    for (const e of diff.booked) {
      const title = t('appointment.bookedToast');
      const description = describe(e);
      const open = () => navigate(`/agenda/consultas/${e.id}`);
      toast(title, {
        id: `booked-${e.id}`,
        description,
        duration: 15000,
        action: { label: t('common.view'), onClick: open },
      });
      notifyOs(title, description, open);
    }
    for (const e of diff.rescheduled) {
      const title = t('appointment.rescheduledToast');
      const description = describe(e);
      const open = () => navigate(`/agenda/consultas/${e.id}`);
      toast(title, {
        id: `resched-${e.id}-${e.dateTime.getTime()}`,
        description,
        duration: 15000,
        action: { label: t('common.view'), onClick: open },
      });
      notifyOs(title, description, open);
    }
  }, [events, loading, uid, navigate]);

  return null;
}
