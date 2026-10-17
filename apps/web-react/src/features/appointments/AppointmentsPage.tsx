import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { toast } from 'sonner';
import {
  Plus,
  PawPrint,
  CalendarDays,
  Clock,
  MessageSquare,
  Building2,
  CheckCircle2,
  XCircle,
  Hourglass,
} from 'lucide-react';
import {
  type AppointmentRequest,
  AppointmentRequestStatus,
  TimePreference,
} from '@vetplus/shared';
import { useAuth } from '@/auth/AuthProvider';
import { petsQuery, mapPet, type Pet } from '@/lib/petService';
import {
  petOwnerRequestsQuery,
  mapAppointmentRequest,
  cancelRequest,
} from '@/lib/appointmentRequestService';
import { useCollection } from '@/lib/useFirestore';
import { PageHeader } from '@/components/ui/PageHeader';
import { Card, CardBody } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { EmptyState } from '@/components/ui/EmptyState';
import { Dialog } from '@/components/ui/Dialog';
import { AppointmentRequestFormDialog } from './AppointmentRequestFormDialog';

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

export function AppointmentsPage() {
  const { firebaseUser, profile, connectedClinic } = useAuth();
  const navigate = useNavigate();
  const uid = firebaseUser?.uid ?? '';

  const petQ = useMemo(() => (uid ? petsQuery(uid) : null), [uid]);
  const { data: pets } = useCollection<Pet>(petQ, mapPet);

  const reqQ = useMemo(() => (uid ? petOwnerRequestsQuery(uid) : null), [uid]);
  const { data: requestsRaw, loading } = useCollection<AppointmentRequest>(
    reqQ,
    mapAppointmentRequest,
  );
  const requests = useMemo(
    () =>
      [...requestsRaw]
        .filter((r) => r.status !== AppointmentRequestStatus.cancelled)
        .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime()),
    [requestsRaw],
  );

  const [formOpen, setFormOpen] = useState(false);
  const [cancelTarget, setCancelTarget] = useState<AppointmentRequest | null>(null);
  const [cancelling, setCancelling] = useState(false);

  const doCancel = async () => {
    if (!cancelTarget) return;
    setCancelling(true);
    try {
      await cancelRequest(cancelTarget.id);
      toast.success('Request cancelled');
      setCancelTarget(null);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not cancel request');
    } finally {
      setCancelling(false);
    }
  };

  if (!connectedClinic) {
    return (
      <div>
        <PageHeader
          title="Appointments"
          subtitle="Request appointments with your clinic and track their status."
        />
        <EmptyState
          icon={<Building2 size={36} />}
          title="No clinic connected"
          description="Connect to a clinic to request appointments."
          action={<Button onClick={() => navigate('/profile')}>Connect a clinic</Button>}
        />
      </div>
    );
  }

  return (
    <div>
      <PageHeader
        eyebrow="Bookings"
        title="Appointments"
        subtitle={`Requests to ${connectedClinic.name}.`}
        actions={
          <Button onClick={() => setFormOpen(true)}>
            <Plus size={16} /> New request
          </Button>
        }
      />

      {loading && requests.length === 0 ? null : requests.length === 0 ? (
        <EmptyState
          icon={<CalendarDays size={36} />}
          title="No appointment requests"
          description="Request an appointment with your clinic and track its status here."
          action={<Button onClick={() => setFormOpen(true)}>Request appointment</Button>}
        />
      ) : (
        <div className="space-y-3">
          {requests.map((r) => {
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
                    {r.status === AppointmentRequestStatus.pending && (
                      <Button variant="ghost" onClick={() => setCancelTarget(r)}>
                        Cancel
                      </Button>
                    )}
                  </div>

                  <div className="flex items-center gap-2 font-medium text-foreground">
                    <PawPrint size={16} className="text-primary" />
                    {r.petName}
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

                  {r.responseMessage && (
                    <div className="flex items-start gap-2 rounded-(--radius-md) bg-secondary p-3 text-sm text-muted-foreground">
                      <MessageSquare size={15} className="mt-0.5 shrink-0" />
                      <p className="italic">{r.responseMessage}</p>
                    </div>
                  )}
                </CardBody>
              </Card>
            );
          })}
        </div>
      )}

      <AppointmentRequestFormDialog
        open={formOpen}
        onClose={() => setFormOpen(false)}
        clinicId={connectedClinic.id}
        petOwnerId={uid}
        petOwnerName={profile?.displayName?.trim() || profile?.email || ''}
        pets={pets}
      />

      <Dialog
        open={Boolean(cancelTarget)}
        onClose={() => (cancelling ? undefined : setCancelTarget(null))}
        title="Cancel request?"
        description={
          cancelTarget
            ? `Cancel the appointment request for ${cancelTarget.petName}? This can't be undone.`
            : ''
        }
        footer={
          <>
            <Button variant="outline" disabled={cancelling} onClick={() => setCancelTarget(null)}>
              Keep it
            </Button>
            <Button variant="destructive" loading={cancelling} onClick={() => void doCancel()}>
              Cancel request
            </Button>
          </>
        }
      />
    </div>
  );
}
