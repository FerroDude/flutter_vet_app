import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { toast } from 'sonner';
import {
  CalendarDays,
  ChevronLeft,
  ChevronRight,
  MapPin,
  PawPrint,
  Pencil,
  Plus,
  Trash2,
  User,
} from 'lucide-react';
import { useAuth } from '@/auth/AuthProvider';
import { useVetAppointments } from '@/lib/useVetAppointments';
import { deleteEvent, type AppointmentEvent } from '@/lib/eventService';
import { PageHeader } from '@/components/ui/PageHeader';
import { Card } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { EmptyState } from '@/components/ui/EmptyState';
import { cn } from '@/lib/cn';
import { VetAppointmentDialog } from './VetAppointmentDialog';

const WEEKDAYS = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
const monthFmt = new Intl.DateTimeFormat('pt-PT', { month: 'long', year: 'numeric' });
const dayHeadFmt = new Intl.DateTimeFormat('pt-PT', { weekday: 'long', day: 'numeric', month: 'long' });
const shortDayFmt = new Intl.DateTimeFormat('pt-PT', { weekday: 'short', day: 'numeric', month: 'short' });
const timeFmt = new Intl.DateTimeFormat('pt-PT', { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' });

function dayKey(d: Date): string {
  return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
}

function startOfDay(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

/** Month grid cells, Monday first; null pads the first week. */
function monthCells(month: Date): (Date | null)[] {
  const first = new Date(month.getFullYear(), month.getMonth(), 1);
  const lead = (first.getDay() + 6) % 7;
  const days = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
  const cells: (Date | null)[] = Array.from({ length: lead }, () => null);
  for (let d = 1; d <= days; d++) cells.push(new Date(month.getFullYear(), month.getMonth(), d));
  return cells;
}

export function VetAgendaPage() {
  const { firebaseUser, profile } = useAuth();
  const navigate = useNavigate();
  const uid = firebaseUser?.uid ?? '';
  const vetName = profile?.displayName?.trim() || profile?.email || 'Veterinária';
  const { appointments, error } = useVetAppointments(uid);

  const today = startOfDay(new Date());
  const [viewMonth, setViewMonth] = useState(new Date(today.getFullYear(), today.getMonth(), 1));
  const [selectedDay, setSelectedDay] = useState(today);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<AppointmentEvent | null>(null);

  const byDay = useMemo(() => {
    const m = new Map<string, AppointmentEvent[]>();
    for (const a of appointments) {
      const k = dayKey(a.dateTime);
      (m.get(k) ?? m.set(k, []).get(k)!).push(a);
    }
    return m;
  }, [appointments]);

  const selected = byDay.get(dayKey(selectedDay)) ?? [];
  const upcoming = useMemo(() => {
    const now = Date.now();
    return appointments.filter((a) => a.dateTime.getTime() >= now).slice(0, 8);
  }, [appointments]);

  const shiftMonth = (n: number) =>
    setViewMonth((m) => new Date(m.getFullYear(), m.getMonth() + n, 1));

  const openNew = () => {
    setEditing(null);
    setDialogOpen(true);
  };

  const remove = async (a: AppointmentEvent) => {
    const who = a.clientName ? ` com ${a.clientName}` : '';
    if (!window.confirm(`Cancelar a consulta${who}? Sai também do calendário do cliente.`)) return;
    try {
      await deleteEvent(a.userId, a.id);
      toast.success('Consulta cancelada');
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Não foi possível cancelar');
    }
  };

  const row = (a: AppointmentEvent, showDay = false) => (
    <Card key={`${a.userId}/${a.id}`} className="p-3">
      <div className="flex items-start gap-3">
        <div className="w-14 shrink-0 text-center">
          <p className="font-display text-lg font-bold tabular-nums leading-tight text-foreground">
            {timeFmt.format(a.dateTime)}
          </p>
          {showDay && (
            <p className="text-[11px] text-muted-foreground">{shortDayFmt.format(a.dateTime)}</p>
          )}
        </div>
        <div className="min-w-0 flex-1">
          <p className="break-words font-medium text-foreground">{a.title}</p>
          <p className="flex flex-wrap items-center gap-x-3 gap-y-0.5 text-xs text-muted-foreground">
            <button
              type="button"
              onClick={() => navigate(`/patients/${a.userId}`)}
              className="inline-flex items-center gap-1 hover:text-foreground hover:underline"
            >
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
            <p className="mt-1 whitespace-pre-wrap break-words text-xs text-muted-foreground">
              {a.description}
            </p>
          )}
        </div>
        <div className="flex shrink-0 items-center gap-1">
          <button
            type="button"
            onClick={() => {
              setEditing(a);
              setDialogOpen(true);
            }}
            className="rounded-(--radius-sm) p-1.5 text-muted-foreground hover:bg-secondary"
            aria-label="Editar consulta"
          >
            <Pencil size={15} />
          </button>
          <button
            type="button"
            onClick={() => void remove(a)}
            className="rounded-(--radius-sm) p-1.5 text-muted-foreground hover:bg-secondary hover:text-destructive"
            aria-label="Cancelar consulta"
          >
            <Trash2 size={15} />
          </button>
        </div>
      </div>
    </Card>
  );

  return (
    <div>
      <PageHeader
        eyebrow="Agenda"
        title="Consultas"
        subtitle="As consultas marcadas com os seus clientes."
        actions={
          <Button onClick={openNew}>
            <Plus size={16} /> Nova consulta
          </Button>
        }
      />

      {error && (
        <p className="mb-4 rounded-(--radius-md) bg-destructive/10 p-3 text-sm text-destructive">
          {/index/i.test(error.message)
            ? 'A agenda precisa de um índice novo no Firestore. Publique firestore.indexes.json.'
            : 'Não foi possível carregar a agenda.'}
        </p>
      )}

      <div className="grid gap-6 lg:grid-cols-[1.3fr_1fr]">
        <Card className="p-4">
          <div className="mb-4 flex items-center justify-between">
            <h2 className="font-display text-lg font-semibold capitalize text-foreground">
              {monthFmt.format(viewMonth)}
            </h2>
            <div className="flex items-center gap-1">
              <IconBtn label="Mês anterior" onClick={() => shiftMonth(-1)}>
                <ChevronLeft size={18} />
              </IconBtn>
              <button
                type="button"
                onClick={() => {
                  setViewMonth(new Date(today.getFullYear(), today.getMonth(), 1));
                  setSelectedDay(today);
                }}
                className="rounded-(--radius-sm) px-2 py-1 text-xs font-medium text-muted-foreground hover:bg-secondary"
              >
                Hoje
              </button>
              <IconBtn label="Mês seguinte" onClick={() => shiftMonth(1)}>
                <ChevronRight size={18} />
              </IconBtn>
            </div>
          </div>

          <div className="grid grid-cols-7 gap-1">
            {WEEKDAYS.map((w) => (
              <div key={w} className="pb-1 text-center text-xs font-medium text-muted-foreground">
                {w}
              </div>
            ))}
            {monthCells(viewMonth).map((cell, i) => {
              if (!cell) return <div key={i} />;
              const count = byDay.get(dayKey(cell))?.length ?? 0;
              const isSelected = dayKey(cell) === dayKey(selectedDay);
              const isToday = dayKey(cell) === dayKey(today);
              return (
                <button
                  key={i}
                  type="button"
                  onClick={() => setSelectedDay(cell)}
                  aria-label={`${dayHeadFmt.format(cell)}${count ? `, ${count} consultas` : ''}`}
                  className={cn(
                    'flex aspect-square flex-col items-center justify-start rounded-(--radius-sm) p-1 text-sm transition-colors',
                    isSelected ? 'bg-primary text-primary-foreground' : 'text-foreground hover:bg-secondary',
                  )}
                >
                  <span
                    className={cn(
                      'flex h-6 w-6 items-center justify-center rounded-full text-xs',
                      isToday && !isSelected && 'bg-primary-light font-semibold text-primary',
                    )}
                  >
                    {cell.getDate()}
                  </span>
                  {count > 0 && (
                    <span
                      className={cn(
                        'mt-0.5 rounded-full px-1.5 text-[10px] font-semibold leading-4',
                        isSelected ? 'bg-primary-foreground text-primary' : 'bg-event-appointment/15 text-foreground',
                      )}
                    >
                      {count}
                    </span>
                  )}
                </button>
              );
            })}
          </div>
        </Card>

        <div className="space-y-6">
          <section>
            <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
              <h2 className="font-display text-lg font-semibold first-letter:uppercase text-foreground">
                {dayHeadFmt.format(selectedDay)}
              </h2>
              <Button variant="ghost" className="h-8 px-3 text-xs" onClick={openNew}>
                <Plus size={14} /> Marcar neste dia
              </Button>
            </div>
            {selected.length === 0 ? (
              <EmptyState icon={<CalendarDays size={32} />} title="Sem consultas" description="Nada marcado neste dia." />
            ) : (
              <div className="space-y-2">{selected.map((a) => row(a))}</div>
            )}
          </section>

          {upcoming.length > 0 && (
            <section>
              <h2 className="mb-3 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                Próximas consultas
              </h2>
              <div className="space-y-2">{upcoming.map((a) => row(a, true))}</div>
            </section>
          )}
        </div>
      </div>

      <VetAppointmentDialog
        open={dialogOpen}
        onClose={() => {
          setDialogOpen(false);
          setEditing(null);
        }}
        vetId={uid}
        vetName={vetName}
        defaultDay={selectedDay}
        existing={editing}
        others={appointments}
      />
    </div>
  );
}

function IconBtn({ children, onClick, label }: { children: React.ReactNode; onClick: () => void; label: string }) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      className="rounded-(--radius-sm) p-1.5 text-muted-foreground hover:bg-secondary hover:text-foreground"
    >
      {children}
    </button>
  );
}
