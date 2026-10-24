import { useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { toast } from 'sonner';
import { ArrowLeft } from 'lucide-react';
import { EventType, MessageType } from '@vetplus/shared';
import { useAuth } from '@/auth/AuthProvider';
import { useCollection, useDoc } from '@/lib/useFirestore';
import {
  cancelAppointmentAsClient,
  eventDoc,
  mapEvent,
  type AppointmentEvent,
  type CalendarEvent,
} from '@/lib/eventService';
import { petsQuery, mapPet, type Pet } from '@/lib/petService';
import { sendMessage, useRooms } from '@/lib/chatService';
import { dateTimeFmt, errorMessage, eventTitle } from '@/lib/format';
import { cn } from '@/lib/cn';
import { PageSpinner } from '@/components/Spinner';
import { Card, CardBody } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Dialog } from '@/components/ui/Dialog';
import { EmptyState } from '@/components/ui/EmptyState';
import { Textarea } from '@/components/ui/Textarea';
import { t } from '@/i18n';

/** Client view of one appointment: details + one-shot cancel with reason. */
export function AppointmentPage() {
  const { eventId = '' } = useParams<{ eventId: string }>();
  const navigate = useNavigate();
  const { firebaseUser, profile } = useAuth();
  const uid = firebaseUser?.uid ?? '';

  const ref = useMemo(() => (uid && eventId ? eventDoc(uid, eventId) : null), [uid, eventId]);
  const { data: event, loading } = useDoc<CalendarEvent>(ref, mapEvent);

  const pq = useMemo(() => (uid ? petsQuery(uid) : null), [uid]);
  const { data: pets } = useCollection<Pet>(pq, mapPet);
  const petName = useMemo(() => new Map(pets.map((p) => [p.id, p.name])), [pets]);

  const { rooms } = useRooms('petOwnerId', uid);

  const [cancelOpen, setCancelOpen] = useState(false);
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);

  if (loading) return <PageSpinner />;
  if (!event || event.type !== EventType.appointment) {
    return (
      <EmptyState
        title={t('appointment.notFound')}
        action={<Button onClick={() => navigate('/agenda')}>{t('appointment.backToAgenda')}</Button>}
      />
    );
  }

  const appt = event as AppointmentEvent;
  const cancelled = Boolean(appt.cancelledAt);
  const past = appt.dateTime.getTime() < Date.now();
  const status = cancelled
    ? { label: t('appointment.status.cancelled'), classes: 'bg-destructive/15 text-destructive' }
    : past
      ? { label: t('appointment.status.done'), classes: 'bg-secondary text-muted-foreground' }
      : { label: t('appointment.status.scheduled'), classes: 'bg-primary-light text-primary' };

  const pet = (appt.petId && petName.get(appt.petId)) || appt.petName || null;
  const canCancel = Boolean(appt.bookedByVetId) && !cancelled && !past;

  const confirmCancel = async () => {
    const trimmed = reason.trim();
    if (!trimmed) return;
    setBusy(true);
    try {
      await cancelAppointmentAsClient({ clientId: uid, eventId: appt.id, reason: trimmed });
      const room = rooms[0];
      if (room) {
        try {
          await sendMessage({
            roomId: room.id,
            senderId: uid,
            senderName: profile?.displayName?.trim() || profile?.email || t('common.client'),
            senderRole: 'pet_owner',
            content: t('appointment.cancelMessage', {
              date: dateTimeFmt.format(appt.dateTime),
              pet: pet ? ` (${pet})` : '',
              reason: trimmed,
            }),
            type: MessageType.text,
            metadata: { kind: 'appointment_cancelled', eventId: appt.id },
          });
        } catch {
          toast.error(t('appointment.cancelWarnFailed'));
        }
      }
      toast.success(t('appointment.cancelledOk'));
      setCancelOpen(false);
    } catch (e) {
      toast.error(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="mx-auto max-w-2xl">
      <button
        type="button"
        onClick={() => navigate('/agenda')}
        className="mb-4 inline-flex items-center gap-1.5 text-sm font-medium text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft size={16} /> {t('common.agenda')}
      </button>

      <div className="mb-6 flex flex-wrap items-center gap-3">
        <h1 className="break-words font-display text-3xl font-bold text-foreground">{eventTitle(appt.title)}</h1>
        <span className={cn('rounded-full px-2.5 py-1 text-xs font-semibold', status.classes)}>
          {status.label}
        </span>
      </div>

      <Card>
        <CardBody>
          <dl className="grid grid-cols-1 gap-x-8 gap-y-3 sm:grid-cols-2">
            <Detail label={t('appointment.dateTime')} value={dateTimeFmt.format(appt.dateTime)} />
            <Detail label={t('common.pet')} value={pet ?? '—'} />
            <Detail label={t('common.vet')} value={appt.vetName || '—'} />
            {appt.location && <Detail label={t('appointment.location')} value={appt.location} />}
            {cancelled && appt.cancelledAt && (
              <Detail label={t('appointment.cancelledAt')} value={dateTimeFmt.format(appt.cancelledAt)} />
            )}
            {cancelled && appt.cancelReason && <Detail label={t('appointment.reason')} value={appt.cancelReason} />}
          </dl>
          {appt.description && (
            <div className="mt-4 border-t border-border pt-4">
              <Detail label={t('appointment.notes')} value={appt.description} />
            </div>
          )}
        </CardBody>
      </Card>

      {canCancel && (
        <div className="mt-6 border-t border-border pt-6">
          <Button variant="destructive" onClick={() => setCancelOpen(true)}>
            {t('appointment.cancel')}
          </Button>
        </div>
      )}

      <Dialog
        open={cancelOpen}
        onClose={() => (busy ? undefined : setCancelOpen(false))}
        title={t('appointment.cancel')}
        description={t('appointment.cancel.desc')}
        footer={
          <>
            <Button variant="outline" disabled={busy} onClick={() => setCancelOpen(false)}>
              {t('common.keep')}
            </Button>
            <Button
              variant="destructive"
              loading={busy}
              disabled={!reason.trim()}
              onClick={() => void confirmCancel()}
            >
              {t('appointment.cancel')}
            </Button>
          </>
        }
      >
        <Textarea
          label={t('appointment.reason')}
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          placeholder={t('appointment.reasonPlaceholder')}
        />
      </Dialog>
    </div>
  );
}

function Detail({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-xs font-medium uppercase tracking-wide text-muted-foreground">{label}</dt>
      <dd className="mt-0.5 whitespace-pre-wrap break-words text-sm text-foreground">{value}</dd>
    </div>
  );
}
