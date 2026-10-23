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
  vetRequestsQuery,
  mapAppointmentRequest,
  confirmRequest,
  denyRequest,
  linkChatRoom,
} from '@/lib/appointmentRequestService';
import { TextField } from '@/components/ui/TextField';
import { findOrCreateOneOnOneChat } from '@/lib/chatService';
import { chatRoomPath } from '@/features/chat/useSelectedChatRoom';
import { PageHeader } from '@/components/ui/PageHeader';
import { Card, CardBody } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { EmptyState } from '@/components/ui/EmptyState';
import { Dialog } from '@/components/ui/Dialog';
import { Textarea } from '@/components/ui/Textarea';

const TIME_SHORT: Record<TimePreference, string> = {
  [TimePreference.anyTime]: 'Qualquer hora',
  [TimePreference.morning]: 'Manhã',
  [TimePreference.afternoon]: 'Tarde',
  [TimePreference.evening]: 'Noite',
};

const STATUS_META: Record<
  AppointmentRequestStatus,
  { label: string; classes: string; icon: typeof Hourglass }
> = {
  [AppointmentRequestStatus.pending]: {
    label: 'Pendente',
    classes: 'bg-warning/15 text-warning',
    icon: Hourglass,
  },
  [AppointmentRequestStatus.confirmed]: {
    label: 'Confirmado',
    classes: 'bg-primary-light text-primary',
    icon: CheckCircle2,
  },
  [AppointmentRequestStatus.denied]: {
    label: 'Recusado',
    classes: 'bg-destructive/15 text-destructive',
    icon: XCircle,
  },
  [AppointmentRequestStatus.cancelled]: {
    label: 'Cancelado',
    classes: 'bg-muted text-muted-foreground',
    icon: XCircle,
  },
};

const dateFmt = new Intl.DateTimeFormat('pt-PT', { month: 'short', day: 'numeric' });

function dateRange(r: AppointmentRequest): string {
  const start = dateFmt.format(r.preferredDateStart);
  const end = dateFmt.format(r.preferredDateEnd);
  return start === end ? start : `${start} – ${end}`;
}

type Tab = 'pending' | 'handled';

function toDatetimeLocal(d: Date): string {
  const pad = (n: number) => `${n}`.padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function defaultConfirmTime(start: Date): string {
  const d = new Date(start);
  if (d.getHours() === 0 && d.getMinutes() === 0) d.setHours(9, 0, 0, 0);
  return toDatetimeLocal(d);
}

export function AppointmentQueuePage() {
  const { firebaseUser, profile, connectedClinic, role } = useAuth();
  const navigate = useNavigate();
  const uid = firebaseUser?.uid ?? '';
  const staffName = profile?.displayName?.trim() || profile?.email || 'Vet';
  const clinicId = connectedClinic?.id ?? '';
  const isVet = role === 'vet';

  const q = useMemo(() => {
    if (isVet && uid) return vetRequestsQuery(uid);
    return clinicId ? clinicRequestsQuery(clinicId) : null;
  }, [isVet, uid, clinicId]);
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
  const [when, setWhen] = useState('');
  const [busy, setBusy] = useState(false);

  const list = tab === 'pending' ? pending : handled;

  const doConfirm = async () => {
    if (!confirmTarget) return;
    const dateTime = new Date(when);
    if (!when || Number.isNaN(dateTime.getTime())) {
      toast.error('Escolha a data e a hora.');
      return;
    }
    setBusy(true);
    try {
      await confirmRequest({
        request: confirmTarget,
        handledBy: uid,
        handledByName: staffName,
        message: message.trim() ? message.trim() : null,
        dateTime,
      });
      toast.success('Pedido confirmado');
      setConfirmTarget(null);
      setMessage('');
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Não foi possível confirmar');
    } finally {
      setBusy(false);
    }
  };

  const doDeny = async () => {
    if (!denyTarget) return;
    if (!message.trim()) {
      toast.error('Indique o motivo da recusa.');
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
      toast.success('Pedido recusado');
      setDenyTarget(null);
      setMessage('');
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Não foi possível recusar');
    } finally {
      setBusy(false);
    }
  };

  const openChat = async (r: AppointmentRequest) => {
    try {
      const roomId = await findOrCreateOneOnOneChat({
        petOwnerId: r.petOwnerId,
        petOwnerName: r.petOwnerName,
        staffId: uid,
        staffName,
        staffRole: 'vet',
        petIds: r.petId ? [r.petId] : [],
        topic: `Marcação: ${r.petName}`,
      });
      await linkChatRoom(r.id, roomId).catch(() => {});
      toast.success('Conversa aberta');
      navigate(chatRoomPath(roomId));
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Não foi possível abrir a conversa');
    }
  };

  if (!isVet && !connectedClinic) {
    return (
      <div>
        <PageHeader title="Pedidos de marcação" />
        <EmptyState
          icon={<Building2 size={36} />}
          title="Sem clínica"
          description="Esta conta ainda não está ligada a uma clínica."
        />
      </div>
    );
  }

  return (
    <div>
      <PageHeader
        eyebrow="Fila"
        title="Pedidos de marcação"
        subtitle={isVet ? 'Pedidos dos seus clientes.' : `Pedidos de ${connectedClinic?.name ?? 'a clínica'}.`}
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
            {tk === 'pending' ? 'Pendentes' : 'Tratados'}
            {tk === 'pending' && pending.length > 0 ? ` (${pending.length})` : ''}
          </button>
        ))}
      </div>

      {list.length === 0 ? (
        <EmptyState
          icon={<CalendarDays size={36} />}
          title={tab === 'pending' ? 'Sem pedidos pendentes' : 'Ainda nada tratado'}
          description={
            tab === 'pending'
              ? 'Os pedidos novos aparecem aqui.'
              : 'Os pedidos confirmados e recusados aparecem aqui.'
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
                        Recusar
                      </Button>
                      <Button
                        onClick={() => {
                          setMessage('');
                          setWhen(defaultConfirmTime(r.preferredDateStart));
                          setConfirmTarget(r);
                        }}
                      >
                        Confirmar
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
        title="Confirmar pedido"
        description={
          confirmTarget
            ? `Escolha a hora para ${confirmTarget.petName}. Fica no calendário do cliente.`
            : ''
        }
        footer={
          <>
            <Button variant="outline" disabled={busy} onClick={() => setConfirmTarget(null)}>
              Cancelar
            </Button>
            <Button loading={busy} onClick={() => void doConfirm()}>
              Confirmar
            </Button>
          </>
        }
      >
        <div className="space-y-3">
          <TextField
            label="Data e hora"
            type="datetime-local"
            value={when}
            onChange={(e) => setWhen(e.target.value)}
          />
          <Textarea
            label="Nota para o cliente (opcional)"
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            placeholder="O que o cliente deve saber"
          />
        </div>
      </Dialog>

      {/* Deny dialog */}
      <Dialog
        open={Boolean(denyTarget)}
        onClose={() => (busy ? undefined : setDenyTarget(null))}
        title="Recusar pedido"
        description={
          denyTarget
            ? `Recusar a marcação de ${denyTarget.petName}. Indique o motivo.`
            : ''
        }
        footer={
          <>
            <Button variant="outline" disabled={busy} onClick={() => setDenyTarget(null)}>
              Cancelar
            </Button>
            <Button variant="destructive" loading={busy} onClick={() => void doDeny()}>
              Recusar pedido
            </Button>
          </>
        }
      >
        <Textarea
          label="Motivo"
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          placeholder="Explique o motivo e sugira outra altura…"
        />
      </Dialog>
    </div>
  );
}
