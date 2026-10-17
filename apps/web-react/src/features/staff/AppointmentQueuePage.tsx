import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { toast } from 'sonner';
import {
  PawPrint,
  CalendarDays,
  Clock,
  MessageSquare,
  CheckCircle2,
  XCircle,
  Hourglass,
  Building2,
} from 'lucide-react';
import {
  type AppointmentRequest,
  AppointmentRequestStatus,
  TimePreference,
} from '@vetplus/shared';
import { useAuth } from '@/auth/AuthProvider';
import { useCollection } from '@/lib/useFirestore';
import {
  clinicRequestsQuery,
  mapAppointmentRequest,
  confirmRequest,
  denyRequest,
  linkChatRoom,
} from '@/lib/appointmentRequestService';
import { findOrCreateOneOnOneChat } from '@/lib/chatService';
import { PageHeader } from '@/components/ui/PageHeader';
import { Card, CardBody } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { EmptyState } from '@/components/ui/EmptyState';
import { Dialog } from '@/components/ui/Dialog';
import { Textarea } from '@/components/ui/Textarea';

const TIME_SHORT: Record<TimePreference, string> = {
  [TimePreference.anyTime]: 'Any time',
  [TimePreference.morning]: 'Morning',
  [TimePreference.afternoon]: 'Afternoon',
  [TimePreference.evening]: 'Evening',
};

const STATUS_META: Record<
  AppointmentRequestStatus,
  { label: string; classes: string; icon: typeof Hourglass }
> = {
  [AppointmentRequestStatus.pending]: {
    label: 'Pending',
    classes: 'bg-warning/15 text-warning',
    icon: Hourglass,
  },
  [AppointmentRequestStatus.confirmed]: {
    label: 'Confirmed',
    classes: 'bg-primary-light text-primary',
    icon: CheckCircle2,
  },
  [AppointmentRequestStatus.denied]: {
    label: 'Denied',
    classes: 'bg-destructive/15 text-destructive',
    icon: XCircle,
  },
  [AppointmentRequestStatus.cancelled]: {
    label: 'Cancelled',
    classes: 'bg-muted text-muted-foreground',
    icon: XCircle,
  },
};

const dateFmt = new Intl.DateTimeFormat(undefined, { month: 'short', day: 'numeric' });

function dateRange(r: AppointmentRequest): string {
  const start = dateFmt.format(r.preferredDateStart);
  const end = dateFmt.format(r.preferredDateEnd);
  return start === end ? start : `${start} – ${end}`;
}

type Tab = 'pending' | 'handled';

export function AppointmentQueuePage() {
  const { firebaseUser, profile, connectedClinic } = useAuth();
  const navigate = useNavigate();
  const uid = firebaseUser?.uid ?? '';
  const staffName = profile?.displayName?.trim() || profile?.email || 'Clinic';
  const clinicId = connectedClinic?.id ?? '';

  const q = useMemo(() => (clinicId ? clinicRequestsQuery(clinicId) : null), [clinicId]);
  const { data: raw } = useCollection<AppointmentRequest>(q, mapAppointmentRequest);

  const pending = useMemo(
    () =>
      raw
        .filter((r) => r.status === AppointmentRequestStatus.pending)
        .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime()),
    [raw],
  );
  const handled = useMemo(
    () =>
      raw
        .filter(
          (r) =>
            r.status === AppointmentRequestStatus.confirmed ||
            r.status === AppointmentRequestStatus.denied,
        )
        .sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime()),
    [raw],
  );

  const [tab, setTab] = useState<Tab>('pending');
  const [confirmTarget, setConfirmTarget] = useState<AppointmentRequest | null>(null);
  const [denyTarget, setDenyTarget] = useState<AppointmentRequest | null>(null);
  const [message, setMessage] = useState('');
  const [busy, setBusy] = useState(false);

  const list = tab === 'pending' ? pending : handled;

  const doConfirm = async () => {
    if (!confirmTarget) return;
    setBusy(true);
    try {
      await confirmRequest({
        requestId: confirmTarget.id,
        handledBy: uid,
        handledByName: staffName,
        message: message.trim() ? message.trim() : null,
      });
      toast.success('Request confirmed');
      setConfirmTarget(null);
      setMessage('');
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not confirm');
    } finally {
      setBusy(false);
    }
  };

  const doDeny = async () => {
    if (!denyTarget) return;
    if (!message.trim()) {
      toast.error('Please add a reason for the denial.');
      return;
    }
    setBusy(true);
    try {
      await denyRequest({
        requestId: denyTarget.id,
        handledBy: uid,
        handledByName: staffName,
        message: message.trim(),
      });
      toast.success('Request denied');
      setDenyTarget(null);
      setMessage('');
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not deny');
    } finally {
      setBusy(false);
    }
  };

  const openChat = async (r: AppointmentRequest) => {
    try {
      const roomId = await findOrCreateOneOnOneChat({
        clinicId,
        petOwnerId: r.petOwnerId,
        petOwnerName: r.petOwnerName,
        staffId: uid,
        staffName,
        staffRole: 'receptionist',
        petIds: r.petId ? [r.petId] : [],
        topic: `Re: Appointment request for ${r.petName}`,
      });
      await linkChatRoom(r.id, roomId).catch(() => {});
      toast.success('Chat opened');
      navigate('/chat');
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not open chat');
    }
  };

  if (!connectedClinic) {
    return (
      <div>
        <PageHeader title="Appointment requests" />
        <EmptyState
          icon={<Building2 size={36} />}
          title="No clinic"
          description="Your account isn't linked to a clinic yet."
        />
      </div>
    );
  }

  return (
    <div>
      <PageHeader
        eyebrow="Queue"
        title="Appointment requests"
        subtitle={`Requests for ${connectedClinic.name}.`}
      />

      <div className="mb-5 inline-flex rounded-(--radius-pill) border border-border/60 bg-card p-1">
        {(['pending', 'handled'] as Tab[]).map((tk) => (
          <button
            key={tk}
            type="button"
            onClick={() => setTab(tk)}
            className={
              'rounded-(--radius-pill) px-4 py-1.5 text-sm font-medium capitalize transition-colors ' +
              (tab === tk
                ? 'bg-primary text-primary-foreground'
                : 'text-muted-foreground hover:text-foreground')
            }
          >
            {tk}
            {tk === 'pending' && pending.length > 0 ? ` (${pending.length})` : ''}
          </button>
        ))}
      </div>

      {list.length === 0 ? (
        <EmptyState
          icon={<CalendarDays size={36} />}
          title={tab === 'pending' ? 'No pending requests' : 'Nothing handled yet'}
          description={
            tab === 'pending'
              ? 'New appointment requests will appear here.'
              : 'Confirmed and denied requests will appear here.'
          }
        />
      ) : (
        <div className="space-y-3">
          {list.map((r) => {
            const meta = STATUS_META[r.status];
            const StatusIcon = meta.icon;
            return (
              <Card key={r.id}>
                <CardBody className="space-y-3">
                  <div className="flex items-center justify-between gap-3">
                    <span
                      className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-semibold ${meta.classes}`}
                    >
                      <StatusIcon size={13} />
                      {meta.label}
                    </span>
                    <span className="text-xs text-muted-foreground">{r.petOwnerName}</span>
                  </div>

                  <div className="flex items-center gap-2 font-medium text-foreground">
                    <PawPrint size={16} className="text-primary" />
                    {r.petName}
                    {r.petSpecies ? (
                      <span className="text-sm font-normal text-muted-foreground">
                        · {r.petSpecies}
                      </span>
                    ) : null}
                  </div>

                  <div className="flex flex-wrap items-center gap-x-5 gap-y-1 text-sm text-muted-foreground">
                    <span className="inline-flex items-center gap-1.5">
                      <CalendarDays size={14} />
                      {dateRange(r)}
                    </span>
                    <span className="inline-flex items-center gap-1.5">
                      <Clock size={14} />
                      {TIME_SHORT[r.timePreference]}
                    </span>
                  </div>

                  <p className="text-sm text-foreground">{r.reason}</p>
                  {r.notes && <p className="text-sm text-muted-foreground">{r.notes}</p>}

                  {r.responseMessage && (
                    <div className="flex items-start gap-2 rounded-(--radius-md) bg-secondary p-3 text-sm text-muted-foreground">
                      <MessageSquare size={15} className="mt-0.5 shrink-0" />
                      <p className="italic">{r.responseMessage}</p>
                    </div>
                  )}

                  {r.status === AppointmentRequestStatus.pending && (
                    <div className="flex flex-wrap justify-end gap-2 pt-1">
                      <Button variant="ghost" onClick={() => void openChat(r)}>
                        <MessageSquare size={15} /> Chat
                      </Button>
                      <Button
                        variant="outline"
                        onClick={() => {
                          setMessage('');
                          setDenyTarget(r);
                        }}
                      >
                        Deny
                      </Button>
                      <Button
                        onClick={() => {
                          setMessage('');
                          setConfirmTarget(r);
                        }}
                      >
                        Confirm
                      </Button>
                    </div>
                  )}
                </CardBody>
              </Card>
            );
          })}
        </div>
      )}

      {/* Confirm dialog */}
      <Dialog
        open={Boolean(confirmTarget)}
        onClose={() => (busy ? undefined : setConfirmTarget(null))}
        title="Confirm request"
        description={
          confirmTarget
            ? `Confirm the appointment request for ${confirmTarget.petName}. You can add an optional note for the owner.`
            : ''
        }
        footer={
          <>
            <Button variant="outline" disabled={busy} onClick={() => setConfirmTarget(null)}>
              Cancel
            </Button>
            <Button loading={busy} onClick={() => void doConfirm()}>
              Confirm
            </Button>
          </>
        }
      >
        <Textarea
          label="Note to owner (optional)"
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          placeholder="e.g., We booked you for Tuesday at 3pm…"
        />
      </Dialog>

      {/* Deny dialog */}
      <Dialog
        open={Boolean(denyTarget)}
        onClose={() => (busy ? undefined : setDenyTarget(null))}
        title="Deny request"
        description={
          denyTarget
            ? `Deny the appointment request for ${denyTarget.petName}. Please include a reason.`
            : ''
        }
        footer={
          <>
            <Button variant="outline" disabled={busy} onClick={() => setDenyTarget(null)}>
              Cancel
            </Button>
            <Button variant="destructive" loading={busy} onClick={() => void doDeny()}>
              Deny request
            </Button>
          </>
        }
      >
        <Textarea
          label="Reason"
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          placeholder="Let the owner know why, and suggest alternatives…"
        />
      </Dialog>
    </div>
  );
}
