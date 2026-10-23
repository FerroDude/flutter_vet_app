import { useMemo, useState } from 'react';
import { toast } from 'sonner';
import {
  Activity,
  BellPlus,
  CalendarClock,
  CalendarDays,
  Check,
  MapPin,
  MessageSquare,
  Pencil,
  Pill,
  Plus,
  Stethoscope,
  Trash2,
} from 'lucide-react';
import {
  AppointmentRequestStatus,
  EventType,
  SYMPTOM_LABELS,
  dosesExpectedOnDate,
  dosesTakenOnDate,
  frequencyDisplay,
  isActive,
  isDoseScheduledOnDate,
  type AppointmentRequest,
  type Medication,
  type PetSymptom,
} from '@vetplus/shared';
import { useAuth } from '@/auth/AuthProvider';
import { useCollection } from '@/lib/useFirestore';
import { eventsQuery, mapEvent, deleteEvent, setEventCompleted, type CalendarEvent } from '@/lib/eventService';
import { petsQuery, mapPet, deleteSymptom, type Pet } from '@/lib/petService';
import { logDoseTaken } from '@/lib/medicationService';
import { useAllMedications } from '@/lib/useAllMedications';
import { useAllSymptoms } from '@/lib/useAllSymptoms';
import { cancelRequest, useRequests } from '@/lib/appointmentRequestService';
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
import { MonthGrid, Dots } from '@/components/ui/MonthGrid';
import { useConfirm } from '@/components/ui/Confirm';
import { MedicationFormDialog } from '@/features/medications/MedicationFormDialog';
import { SymptomFormDialog } from '@/features/symptoms/SymptomFormDialog';
import { PetPickerDialog } from '@/features/pets/PetPickerDialog';
import { EventFormDialog } from './EventFormDialog';
import { RequestFormDialog } from './RequestFormDialog';

type AddType = 'reminder' | 'medication' | 'symptom';

const vetBooked = (e: CalendarEvent) => e.type === EventType.appointment && Boolean(e.bookedByVetId);

/** Client agenda: requests to the vet, the month calendar and upcoming visits. */
export function AgendaPage() {
  const { firebaseUser, profile } = useAuth();
  const uid = firebaseUser?.uid ?? '';
  const vetId = profile?.vetId ?? '';
  const confirm = useConfirm();

  const eq = useMemo(() => (uid ? eventsQuery(uid) : null), [uid]);
  const { data: allEvents } = useCollection<CalendarEvent>(eq, mapEvent);
  // Legacy medication-type events are ignored; medications come from the pets.
  const events = useMemo(() => allEvents.filter((e) => e.type !== EventType.medication), [allEvents]);

  const pq = useMemo(() => (uid ? petsQuery(uid) : null), [uid]);
  const { data: pets } = useCollection<Pet>(pq, mapPet);
  const petName = useMemo(() => new Map(pets.map((p) => [p.id, p.name])), [pets]);

  const activeMeds = useAllMedications(uid).filter(isActive);
  const symptoms = useAllSymptoms(uid);
  const { requests } = useRequests('petOwnerId', uid);

  const today = startOfDay(new Date());
  const [month, setMonth] = useState(new Date(today.getFullYear(), today.getMonth(), 1));
  const [day, setDay] = useState(today);

  const [requestOpen, setRequestOpen] = useState(false);
  const [addOpen, setAddOpen] = useState(false);
  const [picking, setPicking] = useState<AddType | null>(null);
  const [form, setForm] = useState<{ type: AddType; petId?: string } | null>(null);
  const [editing, setEditing] = useState<CalendarEvent | null>(null);

  const byDay = useMemo(() => {
    const m = new Map<string, { events: CalendarEvent[]; symptoms: PetSymptom[] }>();
    const slot = (d: Date) => {
      const k = dayKey(d);
      return m.get(k) ?? m.set(k, { events: [], symptoms: [] }).get(k)!;
    };
    events.forEach((e) => slot(e.dateTime).events.push(e));
    symptoms.forEach((s) => slot(s.timestamp).symptoms.push(s));
    return m;
  }, [events, symptoms]);

  const selected = byDay.get(dayKey(day)) ?? { events: [], symptoms: [] };
  const selectedMeds = activeMeds.filter((m) => isDoseScheduledOnDate(m, day));

  // Pending requests, plus denied ones from the last 30 days. Confirmed requests
  // already appear as appointments in the calendar.
  const recentRequests = requests.filter(
    (r) =>
      r.status === AppointmentRequestStatus.pending ||
      (r.status === AppointmentRequestStatus.denied && Date.now() - r.updatedAt.getTime() < 30 * 86_400_000),
  );

  const run = (p: Promise<unknown>, ok?: string) =>
    p.then(() => ok && toast.success(ok)).catch((e) => toast.error(errorMessage(e)));

  const startAdd = (t: AddType) => {
    setAddOpen(false);
    if (t === 'reminder') return setForm({ type: t });
    if (pets.length === 0) return toast.message('Adicione um animal primeiro.');
    if (pets.length === 1) return setForm({ type: t, petId: pets[0]!.id });
    setPicking(t);
  };

  const removeEvent = async (e: CalendarEvent) => {
    if (await confirm({ title: 'Apagar?', description: `Apagar "${e.title}"?`, confirmLabel: 'Apagar', danger: true })) {
      void run(deleteEvent(uid, e.id), 'Apagado');
    }
  };

  const cancel = async (r: AppointmentRequest) => {
    if (
      await confirm({
        title: 'Cancelar pedido?',
        description: `Cancelar o pedido de marcação de ${r.petName}?`,
        confirmLabel: 'Cancelar pedido',
        cancelLabel: 'Manter',
        danger: true,
      })
    ) {
      void run(cancelRequest(r.id), 'Pedido cancelado');
    }
  };

  const marks = (d: Date, isSel: boolean) => {
    const slot = byDay.get(dayKey(d));
    const colors = [
      slot?.events.some((e) => e.type === EventType.appointment) && 'bg-event-appointment',
      activeMeds.some((m) => isDoseScheduledOnDate(m, d)) && 'bg-event-medication',
      slot?.symptoms.length && 'bg-event-symptom',
      slot?.events.some((e) => e.type === EventType.note) && 'bg-accent',
    ].filter(Boolean) as string[];
    return <Dots colors={colors} selected={isSel} />;
  };

  const nothing = selectedMeds.length + selected.events.length + selected.symptoms.length === 0;

  return (
    <div>
      <PageHeader
        eyebrow="Agenda"
        title="Agenda"
        subtitle="Consultas, medicação e sintomas dos seus animais."
        actions={
          <>
            <Button variant="outline" onClick={() => setAddOpen(true)}>
              <Plus size={16} /> Adicionar
            </Button>
            {vetId && (
              <Button onClick={() => setRequestOpen(true)}>
                <CalendarClock size={16} /> Pedir marcação
              </Button>
            )}
          </>
        }
      />

      {recentRequests.length > 0 && (
        <section className="mb-6">
          <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
            Pedidos de marcação
          </h2>
          <div className="space-y-2">
            {recentRequests.map((r) => (
              <RequestRow key={r.id} request={r} onCancel={() => void cancel(r)} />
            ))}
          </div>
        </section>
      )}

      <div className="grid gap-6 lg:grid-cols-[1.4fr_1fr]">
        <MonthGrid month={month} selected={day} onMonthChange={setMonth} onSelect={setDay} marks={marks} />

        <div className="space-y-6">
          <section>
            <h2 className="mb-3 font-display text-lg font-semibold text-foreground first-letter:uppercase">
              {dayHeadFmt.format(day)}
            </h2>
            {nothing ? (
              <EmptyState icon={<CalendarDays size={32} />} title="Nada marcado" description="Nada para este dia." />
            ) : (
              <div className="space-y-2">
                {selectedMeds.map((m) => (
                  <MedRow
                    key={m.id}
                    med={m}
                    day={day}
                    petName={petName.get(m.petId)}
                    onLog={() => {
                      const now = new Date();
                      const at = new Date(day);
                      at.setHours(now.getHours(), now.getMinutes());
                      void run(logDoseTaken(uid, m.petId, m.id, at), 'Dose registada');
                    }}
                  />
                ))}
                {selected.events.map((e) => (
                  <EventRow
                    key={e.id}
                    event={e}
                    petName={e.petId ? petName.get(e.petId) : undefined}
                    onEdit={vetBooked(e) ? undefined : () => setEditing(e)}
                    onDelete={vetBooked(e) ? undefined : () => void removeEvent(e)}
                    onToggle={
                      e.type === EventType.note
                        ? () => void run(setEventCompleted(uid, e.id, !e.isCompleted))
                        : undefined
                    }
                  />
                ))}
                {selected.symptoms.map((s) => (
                  <Row
                    key={s.id}
                    color="bg-event-symptom"
                    title={SYMPTOM_LABELS[s.type]}
                    meta={[timeFmt.format(s.timestamp), petName.get(s.petId), s.note].filter(Boolean).join(' · ')}
                    actions={
                      <IconAction label="Apagar sintoma" danger onClick={() => void run(deleteSymptom(uid, s.petId, s.id))}>
                        <Trash2 size={15} />
                      </IconAction>
                    }
                  />
                ))}
              </div>
            )}
          </section>
        </div>
      </div>

      <Dialog open={addOpen} onClose={() => setAddOpen(false)} title="Adicionar à agenda">
        <div className="grid gap-2">
          <Choice icon={<BellPlus size={18} />} label="Lembrete" hint="Banho, desparasitação…" onClick={() => startAdd('reminder')} />
          <Choice icon={<Pill size={18} />} label="Medicação" hint="Com doses e lembretes" onClick={() => startAdd('medication')} />
          <Choice icon={<Activity size={18} />} label="Sintoma" hint="Para a veterinária ver" onClick={() => startAdd('symptom')} />
        </div>
      </Dialog>

      <PetPickerDialog
        open={picking !== null}
        onClose={() => setPicking(null)}
        pets={pets}
        onPick={(pet) => {
          if (picking) setForm({ type: picking, petId: pet.id });
          setPicking(null);
        }}
      />

      <EventFormDialog
        open={form?.type === 'reminder' || editing !== null}
        onClose={() => {
          setForm(null);
          setEditing(null);
        }}
        uid={uid}
        pets={pets}
        defaultDate={editing?.dateTime ?? day}
        existing={editing}
      />
      <MedicationFormDialog
        open={form?.type === 'medication'}
        onClose={() => setForm(null)}
        uid={uid}
        petId={form?.petId ?? ''}
      />
      <SymptomFormDialog
        open={form?.type === 'symptom'}
        onClose={() => setForm(null)}
        uid={uid}
        petId={form?.petId ?? ''}
        petName={form?.petId ? petName.get(form.petId) : undefined}
        defaultDate={day}
      />
      {vetId && (
        <RequestFormDialog
          open={requestOpen}
          onClose={() => setRequestOpen(false)}
          vetId={vetId}
          petOwnerId={uid}
          petOwnerName={profile?.displayName?.trim() || profile?.email || ''}
          pets={pets}
        />
      )}
    </div>
  );
}

/* ------------------------------- pieces ------------------------------- */

function RequestRow({ request: r, onCancel }: { request: AppointmentRequest; onCancel: () => void }) {
  const status = REQUEST_STATUS[r.status];
  return (
    <Card className="p-3">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div className="min-w-0 flex-1">
          <p className="flex flex-wrap items-center gap-2 text-sm font-medium text-foreground">
            <span className={cn('rounded-full px-2 py-0.5 text-xs font-semibold', status.classes)}>{status.label}</span>
            {r.petName}
          </p>
          <p className="mt-1 text-xs text-muted-foreground">
            {r.status === AppointmentRequestStatus.confirmed && r.bookedDateTime
              ? `Marcado para ${dateTimeFmt.format(r.bookedDateTime)}`
              : `${preferredRange(r.preferredDateStart, r.preferredDateEnd)} · ${TIME_PREFERENCE_LABEL[r.timePreference]}`}
          </p>
          <p className="mt-1 whitespace-pre-wrap break-words text-sm text-foreground">{r.reason}</p>
          {r.responseMessage && (
            <p className="mt-2 flex items-start gap-1.5 rounded-(--radius-sm) bg-secondary p-2 text-xs text-muted-foreground">
              <MessageSquare size={13} className="mt-0.5 shrink-0" />
              <span className="whitespace-pre-wrap break-words">{r.responseMessage}</span>
            </p>
          )}
        </div>
        {r.status === AppointmentRequestStatus.pending && (
          <Button variant="ghost" className="h-8 px-3 text-xs" onClick={onCancel}>
            Cancelar
          </Button>
        )}
      </div>
    </Card>
  );
}

function MedRow({ med, day, petName, onLog }: { med: Medication; day: Date; petName?: string; onLog: () => void }) {
  const expected = dosesExpectedOnDate(med, day);
  const taken = dosesTakenOnDate(med, day);
  const done = expected > 0 && taken >= expected;
  return (
    <Row
      color="bg-event-medication"
      title={[med.name, petName].filter(Boolean).join(' · ')}
      meta={`${med.dosage} · ${frequencyDisplay(med.frequency)} · ${taken}/${expected} tomadas`}
      actions={
        done ? (
          <Check size={18} className="text-success" aria-label="Doses do dia tomadas" />
        ) : (
          <Button variant="outline" className="h-8 px-3 text-xs" onClick={onLog}>
            <Check size={14} /> Registar
          </Button>
        )
      }
    />
  );
}

function EventRow({
  event: e,
  petName,
  onEdit,
  onDelete,
  onToggle,
}: {
  event: CalendarEvent;
  petName?: string;
  onEdit?: () => void;
  onDelete?: () => void;
  onToggle?: () => void;
}) {
  const completed = e.type === EventType.note && e.isCompleted;
  const appt = e.type === EventType.appointment ? e : null;
  return (
    <Row
      color={appt ? 'bg-event-appointment' : 'bg-accent'}
      title={e.title}
      strike={completed}
      meta={[timeFmt.format(e.dateTime), petName, appt?.bookedByVetId && (appt.vetName || 'Veterinária')]
        .filter(Boolean)
        .join(' · ')}
      extra={
        appt?.location ? (
          <span className="inline-flex items-center gap-1">
            <MapPin size={12} /> {appt.location}
          </span>
        ) : appt?.bookedByVetId ? (
          <span className="inline-flex items-center gap-1">
            <Stethoscope size={12} /> Marcada pela veterinária
          </span>
        ) : null
      }
      actions={
        <>
          {onToggle && (
            <IconAction label={completed ? 'Marcar por fazer' : 'Marcar como feito'} onClick={onToggle} active={completed}>
              <Check size={15} />
            </IconAction>
          )}
          {onEdit && (
            <IconAction label="Editar" onClick={onEdit}>
              <Pencil size={15} />
            </IconAction>
          )}
          {onDelete && (
            <IconAction label="Apagar" danger onClick={onDelete}>
              <Trash2 size={15} />
            </IconAction>
          )}
        </>
      }
    />
  );
}

function Row({
  color,
  title,
  meta,
  extra,
  actions,
  strike,
}: {
  color: string;
  title: string;
  meta?: string;
  extra?: React.ReactNode;
  actions?: React.ReactNode;
  strike?: boolean;
}) {
  return (
    <Card className="p-3">
      <div className="flex items-start gap-3">
        <span className={cn('mt-1.5 h-2.5 w-2.5 shrink-0 rounded-full', color)} />
        <div className="min-w-0 flex-1">
          <p className={cn('break-words text-sm font-medium text-foreground', strike && 'line-through opacity-60')}>
            {title}
          </p>
          {meta && <p className="break-words text-xs text-muted-foreground">{meta}</p>}
          {extra && <p className="mt-0.5 text-xs text-muted-foreground">{extra}</p>}
        </div>
        {actions && <div className="flex shrink-0 items-center gap-1">{actions}</div>}
      </div>
    </Card>
  );
}

function IconAction({
  children,
  label,
  onClick,
  danger,
  active,
}: {
  children: React.ReactNode;
  label: string;
  onClick: () => void;
  danger?: boolean;
  active?: boolean;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      className={cn(
        'rounded-(--radius-sm) p-1.5 hover:bg-secondary',
        active ? 'text-primary' : 'text-muted-foreground',
        danger && 'hover:text-destructive',
      )}
    >
      {children}
    </button>
  );
}

function Choice({ icon, label, hint, onClick }: { icon: React.ReactNode; label: string; hint: string; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex items-center gap-3 rounded-(--radius-md) border border-border p-3 text-left transition-colors hover:bg-secondary"
    >
      <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-(--radius-md) bg-primary-light text-primary">
        {icon}
      </span>
      <span>
        <span className="block font-medium text-foreground">{label}</span>
        <span className="block text-xs text-muted-foreground">{hint}</span>
      </span>
    </button>
  );
}
