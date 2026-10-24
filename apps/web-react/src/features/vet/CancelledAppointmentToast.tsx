import { useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { toast } from 'sonner';
import { useAuth } from '@/auth/AuthProvider';
import { useVetAppointments } from '@/lib/useVetAppointments';
import { dateTimeFmt } from '@/lib/format';
import { notifyOs } from '@/features/chat/incomingMessage';
import { t } from '@/i18n';

/** Always-on alert when a client cancels one of the vet's appointments.
 *  Baselines existing cancellations on load, then toasts each new one —
 *  independent of the chat toast (no active-room suppression). */
export function CancelledAppointmentToast() {
  const { firebaseUser } = useAuth();
  const navigate = useNavigate();
  const uid = firebaseUser?.uid ?? '';
  const { appointments, loading } = useVetAppointments(uid);
  const seen = useRef<Set<string> | null>(null);

  useEffect(() => {
    if (!uid || loading) return;
    if (!seen.current) {
      seen.current = new Set(
        appointments.filter((a) => a.cancelledAt).map((a) => `${a.userId}/${a.id}`),
      );
      return;
    }
    for (const a of appointments) {
      if (!a.cancelledAt) continue;
      const key = `${a.userId}/${a.id}`;
      if (seen.current.has(key)) continue;
      seen.current.add(key);
      const description = `${a.clientName || t('common.client')}${a.petName ? ` · ${a.petName}` : ''} · ${dateTimeFmt.format(a.dateTime)}${a.cancelReason ? ` — ${a.cancelReason}` : ''}`;
      const open = () => navigate('/agenda');
      toast(t('vet.cancelToast'), {
        id: `cancel-${key}`,
        description,
        duration: 15000,
        action: { label: t('vet.viewAgenda'), onClick: open },
      });
      notifyOs(t('vet.cancelToast'), description, open);
    }
  }, [appointments, loading, uid, navigate]);

  return null;
}
