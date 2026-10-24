import { useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { toast } from 'sonner';
import { AppointmentRequestStatus } from '@vetplus/shared';
import { useAuth } from '@/auth/AuthProvider';
import { useRequests } from '@/lib/appointmentRequestService';
import { dateTimeFmt } from '@/lib/format';
import { notifyOs } from '@/features/chat/incomingMessage';

/** Always-on alert when the vet confirms one of the client's requests.
 *  Baselines already-confirmed requests on load, then toasts each new one —
 *  independent of the chat toast (no active-room suppression). */
export function ConfirmedRequestToast() {
  const { firebaseUser } = useAuth();
  const navigate = useNavigate();
  const uid = firebaseUser?.uid ?? '';
  const { requests, loading } = useRequests('petOwnerId', uid);
  const seen = useRef<Set<string> | null>(null);

  useEffect(() => {
    if (!uid || loading) return;
    const confirmed = requests.filter((r) => r.status === AppointmentRequestStatus.confirmed);
    if (!seen.current) {
      seen.current = new Set(confirmed.map((r) => r.id));
      return;
    }
    for (const r of confirmed) {
      if (seen.current.has(r.id)) continue;
      seen.current.add(r.id);
      const description =
        [r.petName, r.bookedDateTime ? dateTimeFmt.format(r.bookedDateTime) : '']
          .filter(Boolean)
          .join(' · ') + (r.responseMessage ? ` — ${r.responseMessage}` : '');
      const open = () =>
        navigate(r.calendarEventId ? `/agenda/consultas/${r.calendarEventId}` : '/agenda');
      toast('Consulta confirmada', {
        id: `confirm-${r.id}`,
        description,
        duration: 15000,
        action: { label: 'Ver', onClick: open },
      });
      notifyOs('Consulta confirmada', description, open);
    }
  }, [requests, loading, uid, navigate]);

  return null;
}
