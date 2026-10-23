import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { toast } from 'sonner';
import { CalendarDays, MapPin, MessageSquare, PawPrint, Pencil, Plus, Trash2, User } from 'lucide-react';
import { AppointmentRequestStatus, type AppointmentRequest } from '@vetplus/shared';
import { useAuth } from '@/auth/AuthProvider';
import { useVetAppointments } from '@/lib/useVetAppointments';
import { deleteEvent, type AppointmentEvent } from '@/lib/eventService';
import { confirmRequest, denyRequest, useRequests } from '@/lib/appointmentRequestService';
import { findOrCreateOneOnOneChat } from '@/lib/chatService';
import { chatRoomPath } from '@/features/chat/useSelectedChatRoom';
import {
  REQUEST_STATUS,
  TIME_PREFERENCE_LABEL,
  dateTimeFmt,
  dayHeadFmt,
  dayKey,
  errorMessage,
  preferredRange,
  startOfDay,
  timeFmt,
} from '@/lib/format';
import { cn } from '@/lib/cn';
import { PageHeader } from '@/components/ui/PageHeader';
import { Card } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Dialog } from '@/components/ui/Dialog';
import { EmptyState } from '@/components/ui/EmptyState';
import { TextField } from '@/components/ui/TextField';
import { Textarea } from '@/components/ui/Textarea';
import { MonthGrid } from '@/components/ui/MonthGrid';
import { useConfirm } from '@/components/ui/Confirm';
import { toLocalInput } from '@/features/calendar/EventFormDialog';
import { VetAppointmentDialog } from './VetAppointmentDialog';

/** Vet agenda: pending requests to answer, the month calendar and upcoming visits. */
export function VetAgendaPage() {
  const { firebaseUser, profile } = useAuth();
  const navigate = useNavigate();
  const confirm = useConfirm();
  const uid = firebaseUser?.uid ?? '';
  const vetName = profile?.displayName?.trim() || profile?.email || 'Veterinária';
  const { appointments, error } = useVetAppointments(uid);
  const { requests } = useRequests('vetId', uid);

  const pending = requests.filter((r) => r.status === AppointmentRequestStatus.pending).reverse();
  const handled = requests.filter(
    (r) => r.status === AppointmentRequestStatus.confirmed || r.status === AppointmentRequestStatus.denied,
  );

  const today = startOfDay(new Date());
  const [month, setMonth] = useState(new Date(today.getFullYear(), today.getMonth(), 1));
  const [day, setDay] = useState(today);
  const [showHandled, setShowHandled] = useState(false);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<AppointmentEvent | null>(null);
  const [answering, setAnswering] = useState<{ request: AppointmentRequest; mode: 'confirm' | 'deny' } | null>(null);

  const byDay = useMemo(() => {
    const m = new Map<string, AppointmentEvent[]>();
    appointments.forEach((a) => {
      const k = dayKey(a.dateTime);
      (m.get(k) ?? m.set(k, []).get(k)!).push(a);
    });
    return m;
  }, [appointments]);

  const selected = byDay.get(dayKey(day)) ?? [];

  const openNew = () => {
    setEditing(null);
    setDialogOpen(true);
  };

  const cancel = async (a: AppointmentEvent) => {
    const ok = await confirm({
      title: 'Cancelar consulta?',
      description: `${a.clientName ? `Com ${a.clientName}. ` : ''}Sai também do calendário do cliente.`,
      confirmLabel: 'Cancelar consulta',
      cancelLabel: 'Manter',
      danger: true,
    });
    if (!ok) return;
    try {
      await deleteEvent(a.userId, a.id);
      toast.success('Consulta cancelada');
    } catch (e) {
      toast.error(errorMessage(e));
    }
  };

  const openChat = async (r: AppointmentRequest) => {
    try {
      const roomId = await findOrCreateOneOnOneChat({
        petOwnerId: r.petOwnerId,
        petOwnerName: r.petOwnerName,
        vetId: uid,
        vetName,
      });
      navigate(chatRoomPath(roomId));
    } catch (e) {
      toast.error(errorMessage(e, 'Não foi possível abrir a conversa'));
    }
  };

  return (
    <div>
      <PageHeader
        eyebrow="Agenda"
        title="Agenda"
        subtitle="Pedidos dos clientes e consultas marcadas."
        actions={
          <Button onClick={openNew}>
            <Plus size={16} /> Nova consulta
          </Button>
        }
      />

      {error && (
        <p className="mb-4 rounded-(--radius-md) bg-destructive/10 p-3 text-sm text-destructive">
          Não foi possível carregar a agenda.
        </p>
      )}

      {pending.length > 0 && (
        <section className="mb-6">
          <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
            Pedidos pendentes ({pending.length})
          </h2>
          <div className="space-y-2">
            {pending.map((r) => (
              <RequestCard key={r.id} request={r}>
                <Button variant="ghost" className="h-9" onClick={() => void openChat(r)}>
                  <MessageSquare size={15} /> Chat
                </Button>
                <Button variant="outline" className="h-9" onClick={() => setAnswering({ request: r, mode: 'deny' })}>
                  Recusar
                </Button>
                <Button className="h-9" onClick={() => setAnswering({ request: r, mode: 'confirm' })}>
                  Confirmar
                </Button>
              </RequestCard>
            ))}
          </div>
        </section>
      )}

      <div className="grid gap-6 lg:grid-cols-[1.3fr_1fr]">
        <MonthGrid
          month={month}
          selected={day}
          onMonthChange={setMonth}
          onSelect={setDay}
          marks={(d, isSel) => {
            const n = byDay.get(dayKey(d))?.length ?? 0;
            return n ? (
              <span
                className={cn(
                  'mt-0.5 rounded-full px-1.5 text-[10px] font-semibold leading-4',
                  isSel ? 'bg-primary-foreground text-primary' : 'bg-primary-light text-primary',
                )}
              >
                {n}
              </span>
            ) : null;
          }}
        />

        <div className="space-y-6">
          <section>
            <h2 className="mb-3 font-display text-lg font-semibold text-foreground first-letter:uppercase">
              {dayHeadFmt.format(day)}
            </h2>
            {selected.length === 0 ? (
              <EmptyState icon={<CalendarDays size={32} />} title="Sem consultas" description="Nada marcado neste dia." />
            ) : (
              <div className="space-y-2">
                {selected.map((a) => (
                  <AppointmentRow
                    key={`${a.userId}/${a.id}`}
                    a={a}
                    onClient={() => navigate(`/clients/${a.userId}`)}
                    onEdit={() => {
                      setEditing(a);
                      setDialogOpen(true);
                    }}
                    onCancel={() => void cancel(a)}
                  />
                ))}
              </div>
            )}
          </section>
        </div>
      </div>

      {handled.length > 0 && (
        <section className="mt-8">
          <button
            type="button"
            onClick={() => setShowHandled((v) => !v)}
            className="text-sm font-medium text-muted-foreground hover:text-foreground"
            aria-expanded={showHandled}
          >
            {showHandled ? 'Esconder' : 'Ver'} pedidos tratados ({handled.length})
          </button>
          {showHandled && (
            <div className="mt-3 space-y-2">
              {handled.map((r) => (
                <RequestCard key={r.id} request={r} />
              ))}
            </div>
          )}
        </section>
      )}

      <VetAppointmentDialog
        open={dialogOpen}
        onClose={() => {
          setDialogOpen(false);
          setEditing(null);
        }}
        vetId={uid}
        vetName={vetName}
        defaultDay={day}
        existing={editing}
        others={appointments}
      />

      <AnswerDialog answering={answering} onClose={() => setAnswering(null)} vetId={uid} vetName={vetName} />
    </div>
  );
}

function RequestCard({ request: r, children }: { request: AppointmentRequest; children?: React.ReactNode }) {
  const status = REQUEST_STATUS[r.status];
  return (
    <Card className="p-4">
      <div className="flex flex-wrap items-center gap-2 text-sm">
        <span className={cn('rounded-full px-2 py-0.5 text-xs font-semibold', status.classes)}>{status.label}</span>
        <span className="inline-flex items-center gap-1 font-medium text-foreground">
          <PawPrint size={14} className="text-primary" /> {r.petName}
          {r.petSpecies && <span className="font-normal text-muted-foreground">· {r.petSpecies}</span>}
        </span>
        <span className="text-muted-foreground">· {r.petOwnerName}</span>
      </div>
      <p className="mt-1 text-xs text-muted-foreground">
        {r.status === AppointmentRequestStatus.confirmed && r.bookedDateTime
          ? `Marcado para ${dateTimeFmt.format(r.bookedDateTime)}`
          : `${preferredRange(r.preferredDateStart, r.preferredDateEnd)} · ${TIME_PREFERENCE_LABEL[r.timePreference]}`}
      </p>
      <p className="mt-2 whitespace-pre-wrap break-words text-sm text-foreground">{r.reason}</p>
      {r.notes && <p className="mt-1 whitespace-pre-wrap break-words text-sm text-muted-foreground">{r.notes}</p>}
      {r.responseMessage && (
        <p className="mt-2 rounded-(--radius-sm) bg-secondary p-2 text-xs italic text-muted-foreground">
          {r.responseMessage}
        </p>
      )}
      {children && <div className="mt-3 flex flex-wrap justify-end gap-2">{children}</div>}
    </Card>
  );
}

function AppointmentRow({
  a,
  onClient,
  onEdit,
  onCancel,
}: {
  a: AppointmentEvent;
  onClient: () => void;
  onEdit: () => void;
  onCancel: () => void;
}) {
  return (
    <Card className="p-3">
      <div className="flex items-start gap-3">
        <div className="w-14 shrink-0 text-center">
          <p className="font-display text-lg font-bold tabular-nums leading-tight text-foreground">
            {timeFmt.format(a.dateTime)}
          </p>
        </div>
        <div className="min-w-0 flex-1">
          <p className="break-words font-medium text-foreground">{a.title}</p>
          <p className="flex flex-wrap items-center gap-x-3 gap-y-0.5 text-xs text-muted-foreground">
            <button type="button" onClick={onClient} className="inline-flex items-center gap-1 hover:text-foreground hover:underline">
              <User size={12} /> {a.clientName || 'Cliente'}
            </button>
            {a.petName && (
              <span className="inline-flex items-center gap-1">
                <PawPrint size={12} /> {a.petName}
              </span>
            )}
            {a.location && (
              <span className="inline-flex items-center gap-1">
                <MapPin size={12} /> {a.location}
              </span>
            )}
          </p>
          {a.description && (
            <p className="mt-1 whitespace-pre-wrap break-words text-xs text-muted-foreground">{a.description}</p>
          )}
        </div>
        <div className="flex shrink-0 items-center gap-1">
          <button
            type="button"
            onClick={onEdit}
            aria-label="Editar consulta"
            className="rounded-(--radius-sm) p-1.5 text-muted-foreground hover:bg-secondary"
          >
            <Pencil size={15} />
          </button>
          <button
            type="button"
            onClick={onCancel}
            aria-label="Cancelar consulta"
            className="rounded-(--radius-sm) p-1.5 text-muted-foreground hover:bg-secondary hover:text-destructive"
          >
            <Trash2 size={15} />
          </button>
        </div>
      </div>
    </Card>
  );
}

/** Confirm (pick the time) or deny (reason required) a request. */
function AnswerDialog({
  answering,
  onClose,
  vetId,
  vetName,
}: {
  answering: { request: AppointmentRequest; mode: 'confirm' | 'deny' } | null;
  onClose: () => void;
  vetId: string;
  vetName: string;
}) {
  const r = answering?.request;
  const isConfirm = answering?.mode === 'confirm';
  const [when, setWhen] = useState('');
  const [message, setMessage] = useState('');
  const [busy, setBusy] = useState(false);
  const [lastId, setLastId] = useState<string | null>(null);

  // Reset the form whenever a different request is opened.
  const key = answering ? `${answering.request.id}/${answering.mode}` : null;
  if (key !== lastId) {
    setLastId(key);
    setMessage('');
    if (r) {
      const d = new Date(r.preferredDateStart);
      if (d.getHours() === 0) d.setHours(9, 0, 0, 0);
      setWhen(toLocalInput(d));
    }
  }

  const submit = async () => {
    if (!r) return;
    setBusy(true);
    try {
      if (isConfirm) {
        const dateTime = new Date(when);
        if (!when || Number.isNaN(dateTime.getTime())) throw new Error('Escolha a data e a hora.');
        await confirmRequest({ request: r, vetId, vetName, dateTime, message: message.trim() || null });
        toast.success('Pedido confirmado. Já está no calendário do cliente.');
      } else {
        if (!message.trim()) throw new Error('Indique o motivo da recusa.');
        await denyRequest({ requestId: r.id, vetId, vetName, message: message.trim() });
        toast.success('Pedido recusado');
      }
      onClose();
    } catch (e) {
      toast.error(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog
      open={Boolean(answering)}
      onClose={() => (busy ? undefined : onClose())}
      title={isConfirm ? 'Confirmar pedido' : 'Recusar pedido'}
      description={
        r
          ? isConfirm
            ? `Escolha a hora para ${r.petName}. Fica no calendário do cliente.`
            : `Recusar a marcação de ${r.petName}. Indique o motivo.`
          : undefined
      }
      footer={
        <>
          <Button variant="outline" disabled={busy} onClick={onClose}>
            Cancelar
          </Button>
          <Button variant={isConfirm ? 'primary' : 'destructive'} loading={busy} onClick={() => void submit()}>
            {isConfirm ? 'Confirmar' : 'Recusar pedido'}
          </Button>
        </>
      }
    >
      <div className="space-y-3">
        {isConfirm && (
          <TextField label="Data e hora" type="datetime-local" value={when} onChange={(e) => setWhen(e.target.value)} />
        )}
        <Textarea
          label={isConfirm ? 'Nota para o cliente (opcional)' : 'Motivo'}
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          placeholder={isConfirm ? 'O que o cliente deve saber' : 'Explique o motivo e sugira outra altura…'}
        />
      </div>
    </Dialog>
  );
}
