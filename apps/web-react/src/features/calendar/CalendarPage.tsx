import { useMemo, useState } from 'react';
import {
  ChevronLeft,
  ChevronRight,
  Plus,
  Check,
  Pencil,
  Trash2,
  CalendarDays,
  Pill,
  Stethoscope,
  Activity,
} from 'lucide-react';
import {
  EventType,
  SYMPTOM_LABELS,
  isActive,
  isDoseScheduledOnDate,
  dosesExpectedOnDate,
  dosesTakenOnDate,
  frequencyDisplay,
  type Medication,
  type MedicationStatus,
  type PetSymptom,
} from '@vetplus/shared';
import { useAuth } from '@/auth/AuthProvider';
import {
  eventsQuery,
  mapEvent,
  deleteEvent,
  setEventCompleted,
  type CalendarEvent,
} from '@/lib/eventService';
import { petsQuery, mapPet, deleteSymptom, type Pet } from '@/lib/petService';
import {
  logDoseTaken,
  undoLastDose,
  setMedicationStatus,
  deleteMedication,
} from '@/lib/medicationService';
import { useAllMedications } from '@/lib/useAllMedications';
import { useAllSymptoms } from '@/lib/useAllSymptoms';
import { useCollection } from '@/lib/useFirestore';
import { PageHeader } from '@/components/ui/PageHeader';
import { Card } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { EmptyState } from '@/components/ui/EmptyState';
import { Dialog } from '@/components/ui/Dialog';
import { cn } from '@/lib/cn';
import { MedicationCard } from '@/features/medications/MedicationCard';
import { MedicationFormDialog } from '@/features/medications/MedicationFormDialog';
import { SymptomFormDialog } from '@/features/symptoms/SymptomFormDialog';
import { PetPickerDialog } from '@/features/pets/PetPickerDialog';
import { EventFormDialog } from './EventFormDialog';
import { toast } from 'sonner';

const WEEKDAYS = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
const monthFmt = new Intl.DateTimeFormat('pt-PT', { month: 'long', year: 'numeric' });
const timeFmt = new Intl.DateTimeFormat('pt-PT', { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' });
const dayHeadFmt = new Intl.DateTimeFormat('pt-PT', { weekday: 'long', month: 'long', day: 'numeric' });
const groupFmt = new Intl.DateTimeFormat('pt-PT', { weekday: 'short', month: 'short', day: 'numeric' });

type View = 'calendar' | 'appointments' | 'medications' | 'symptoms';
type AddType = 'appointment' | 'medication' | 'symptom';

function dayKey(d: Date): string {
  return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
}
function sameDay(a: Date, b: Date): boolean {
  return dayKey(a) === dayKey(b);
}
function mondayIndex(d: Date): number {
  return (d.getDay() + 6) % 7;
}

export function CalendarPage() {
  const { firebaseUser } = useAuth();
  const uid = firebaseUser?.uid ?? '';

  const eQuery = useMemo(() => (uid ? eventsQuery(uid) : null), [uid]);
  const { data: allEvents } = useCollection<CalendarEvent>(eQuery, mapEvent);
  // Calendar/appointments ignore legacy medication-type events (mirrors mobile).
  const events = useMemo(() => allEvents.filter((e) => e.type !== EventType.medication), [allEvents]);

  const pQuery = useMemo(() => (uid ? petsQuery(uid) : null), [uid]);
  const { data: pets } = useCollection<Pet>(pQuery, mapPet);
  const petName = useMemo(() => {
    const m = new Map<string, string>();
    pets.forEach((p) => m.set(p.id, p.name));
    return m;
  }, [pets]);

  const meds = useAllMedications(uid);
  const activeMeds = useMemo(() => meds.filter(isActive), [meds]);
  const symptoms = useAllSymptoms(uid);

  const today = useMemo(() => new Date(), []);
  const [view, setView] = useState<View>('calendar');
  const [viewMonth, setViewMonth] = useState(() => new Date(today.getFullYear(), today.getMonth(), 1));
  const [selectedDay, setSelectedDay] = useState(() => new Date(today.getFullYear(), today.getMonth(), today.getDate()));

  // Add flow
  const [addOpen, setAddOpen] = useState(false);
  const [pickingFor, setPickingFor] = useState<AddType | null>(null);
  const [formFor, setFormFor] = useState<{ type: AddType; petId: string } | null>(null);
  const [editingEvent, setEditingEvent] = useState<CalendarEvent | null>(null);

  const eventsByDay = useMemo(() => {
    const m = new Map<string, CalendarEvent[]>();
    for (const e of events) {
      const k = dayKey(e.dateTime);
      (m.get(k) ?? m.set(k, []).get(k)!).push(e);
    }
    return m;
  }, [events]);

  const symptomsByDay = useMemo(() => {
    const m = new Map<string, PetSymptom[]>();
    for (const s of symptoms) {
      const k = dayKey(s.timestamp);
      (m.get(k) ?? m.set(k, []).get(k)!).push(s);
    }
    return m;
  }, [symptoms]);

  const cells = useMemo(() => {
    const first = new Date(viewMonth.getFullYear(), viewMonth.getMonth(), 1);
    const daysInMonth = new Date(viewMonth.getFullYear(), viewMonth.getMonth() + 1, 0).getDate();
    const lead = mondayIndex(first);
    const out: (Date | null)[] = [];
    for (let i = 0; i < lead; i++) out.push(null);
    for (let d = 1; d <= daysInMonth; d++) out.push(new Date(viewMonth.getFullYear(), viewMonth.getMonth(), d));
    while (out.length % 7 !== 0) out.push(null);
    return out;
  }, [viewMonth]);

  const selectedEvents = (eventsByDay.get(dayKey(selectedDay)) ?? [])
    .slice()
    .sort((a, b) => a.dateTime.getTime() - b.dateTime.getTime());
  const selectedSymptoms = (symptomsByDay.get(dayKey(selectedDay)) ?? [])
    .slice()
    .sort((a, b) => a.timestamp.getTime() - b.timestamp.getTime());
  const selectedMeds = activeMeds.filter((m) => isDoseScheduledOnDate(m, selectedDay));

  const shiftMonth = (delta: number) =>
    setViewMonth((m) => new Date(m.getFullYear(), m.getMonth() + delta, 1));

  const startAdd = (t: AddType) => {
    setAddOpen(false);
    if (pets.length === 0) {
      toast.message('Adicione um animal primeiro');
      return;
    }
    if (t === 'appointment' && pets.length === 1 && pets[0]) {
      setFormFor({ type: t, petId: pets[0].id });
      return;
    }
    setPickingFor(t);
  };

  const logMedDose = async (m: Medication, day: Date) => {
    const now = new Date();
    const at = new Date(day.getFullYear(), day.getMonth(), day.getDate(), now.getHours(), now.getMinutes());
    try {
      await logDoseTaken(uid, m.petId, m.id, at);
      toast.success('Dose registada');
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Não foi possível registar a dose');
    }
  };

  return (
    <div>
      <PageHeader
        eyebrow="Agenda"
        title="Calendário"
        subtitle="Consultas, medicação e sintomas dos seus animais."
        actions={
          <Button onClick={() => setAddOpen(true)}>
            <Plus size={18} /> Add
          </Button>
        }
      />

      <Segmented
        value={view}
        onChange={setView}
        options={[
          { value: 'calendar', label: 'Calendário', icon: CalendarDays },
          { value: 'appointments', label: 'Consultas', icon: Stethoscope },
          { value: 'medications', label: 'Medicação', icon: Pill },
          { value: 'symptoms', label: 'Sintomas', icon: Activity },
        ]}
      />

      <div className="mt-6">
        {view === 'calendar' && (
          <div className="grid gap-6 lg:grid-cols-[1.4fr_1fr]">
            <Card className="p-4">
              <div className="mb-4 flex items-center justify-between">
                <h2 className="font-display text-lg font-semibold text-foreground">
                  {monthFmt.format(viewMonth)}
                </h2>
                <div className="flex items-center gap-1">
                  <IconBtn onClick={() => shiftMonth(-1)} label="Mês anterior">
                    <ChevronLeft size={18} />
                  </IconBtn>
                  <button
                    type="button"
                    onClick={() => {
                      const t = new Date();
                      setViewMonth(new Date(t.getFullYear(), t.getMonth(), 1));
                      setSelectedDay(new Date(t.getFullYear(), t.getMonth(), t.getDate()));
                    }}
                    className="rounded-(--radius-sm) px-2 py-1 text-xs font-medium text-muted-foreground hover:bg-secondary"
                  >
                    Hoje
                  </button>
                  <IconBtn onClick={() => shiftMonth(1)} label="Mês seguinte">
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
                {cells.map((cell, i) => {
                  if (!cell) return <div key={i} />;
                  const k = dayKey(cell);
                  const dayEvents = eventsByDay.get(k) ?? [];
                  const hasAppt = dayEvents.some((e) => e.type === EventType.appointment);
                  const hasNote = dayEvents.some((e) => e.type === EventType.note);
                  const hasSymptom = (symptomsByDay.get(k)?.length ?? 0) > 0;
                  const hasMed = activeMeds.some((m) => isDoseScheduledOnDate(m, cell));
                  const isToday = sameDay(cell, today);
                  const isSelected = sameDay(cell, selectedDay);
                  return (
                    <button
                      key={i}
                      type="button"
                      onClick={() => setSelectedDay(cell)}
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
                      <span className="mt-0.5 flex h-1.5 gap-0.5">
                        {hasAppt && <Dot selected={isSelected} className="bg-event-appointment" />}
                        {hasMed && <Dot selected={isSelected} className="bg-event-medication" />}
                        {hasSymptom && <Dot selected={isSelected} className="bg-event-symptom" />}
                        {hasNote && <Dot selected={isSelected} className="bg-accent" />}
                      </span>
                    </button>
                  );
                })}
              </div>
            </Card>

            {/* Day panel */}
            <div>
              <h2 className="mb-3 font-display text-lg font-semibold text-foreground">
                {dayHeadFmt.format(selectedDay)}
              </h2>

              {selectedMeds.length === 0 && selectedEvents.length === 0 && selectedSymptoms.length === 0 ? (
                <EmptyState icon={<CalendarDays size={32} />} title="Nada marcado" description="Adicione algo a este dia." />
              ) : (
                <div className="space-y-4">
                  {selectedMeds.length > 0 && (
                    <Section title="Medicação">
                      {selectedMeds.map((m) => {
                        const expected = dosesExpectedOnDate(m, selectedDay);
                        const taken = dosesTakenOnDate(m, selectedDay);
                        const done = expected > 0 && taken >= expected;
                        return (
                          <Card key={m.id} className="flex items-center gap-3 p-3">
                            <span className={cn('flex h-9 w-9 items-center justify-center rounded-(--radius-md)', done ? 'bg-success/15 text-success' : 'bg-primary-light text-primary')}>
                              {done ? <Check size={18} /> : <Pill size={18} />}
                            </span>
                            <div className="min-w-0 flex-1">
                              <p className="truncate text-sm font-medium text-foreground">
                                {m.name}
                                {petName.get(m.petId) ? ` · ${petName.get(m.petId)}` : ''}
                              </p>
                              <p className="truncate text-xs text-muted-foreground">
                                {m.dosage} · {frequencyDisplay(m.frequency)} · {taken}/{expected} tomadas
                              </p>
                            </div>
                            {!done && (
                              <Button variant="outline" className="h-8 px-3 text-xs" onClick={() => void logMedDose(m, selectedDay)}>
                                <Check size={14} /> Registar
                              </Button>
                            )}
                          </Card>
                        );
                      })}
                    </Section>
                  )}

                  {selectedEvents.length > 0 && (
                    <Section title="Eventos">
                      {selectedEvents.map((e) => (
                        <EventRow
                          key={e.id}
                          event={e}
                          petName={e.petId ? petName.get(e.petId) : undefined}
                          onEdit={() => setEditingEvent(e)}
                          onDelete={() => void deleteEvent(uid, e.id)}
                          onToggle={() => void toggleComplete(uid, e)}
                        />
                      ))}
                    </Section>
                  )}

                  {selectedSymptoms.length > 0 && (
                    <Section title="Sintomas">
                      {selectedSymptoms.map((s) => (
                        <SymptomRow key={s.id} uid={uid} symptom={s} petName={petName.get(s.petId)} />
                      ))}
                    </Section>
                  )}
                </div>
              )}
            </div>
          </div>
        )}

        {view === 'appointments' && (
          <AppointmentsView events={events} petName={petName} uid={uid} onEdit={setEditingEvent} />
        )}

        {view === 'medications' && (
          <MedicationsView uid={uid} meds={meds} petName={petName} />
        )}

        {view === 'symptoms' && <SymptomsView uid={uid} symptoms={symptoms} petName={petName} />}
      </div>

      {/* Add type chooser */}
      <Dialog open={addOpen} onClose={() => setAddOpen(false)} title="Adicionar ao calendário">
        <div className="grid grid-cols-1 gap-2">
          <AddChoice icon={<Stethoscope size={18} />} label="Consulta" onClick={() => startAdd('appointment')} />
          <AddChoice icon={<Pill size={18} />} label="Medicação" onClick={() => startAdd('medication')} />
          <AddChoice icon={<Activity size={18} />} label="Sintoma" onClick={() => startAdd('symptom')} />
        </div>
      </Dialog>

      {/* Pet picker */}
      <PetPickerDialog
        open={pickingFor !== null}
        onClose={() => setPickingFor(null)}
        pets={pets}
        onPick={(pet) => {
          const t = pickingFor;
          setPickingFor(null);
          if (t) setFormFor({ type: t, petId: pet.id });
        }}
      />

      {/* Forms (add flow) */}
      <EventFormDialog
        open={formFor?.type === 'appointment'}
        onClose={() => setFormFor(null)}
        uid={uid}
        pets={pets}
        defaultDate={selectedDay}
        lockToAppointment
        presetPetId={formFor?.petId}
      />
      <MedicationFormDialog
        open={formFor?.type === 'medication'}
        onClose={() => setFormFor(null)}
        uid={uid}
        petId={formFor?.petId ?? ''}
      />
      <SymptomFormDialog
        open={formFor?.type === 'symptom'}
        onClose={() => setFormFor(null)}
        uid={uid}
        petId={formFor?.petId ?? ''}
        petName={formFor ? petName.get(formFor.petId) : undefined}
        defaultDate={selectedDay}
      />

      {/* Edit existing appointment/note */}
      <EventFormDialog
        open={editingEvent !== null}
        onClose={() => setEditingEvent(null)}
        uid={uid}
        pets={pets}
        defaultDate={editingEvent?.dateTime ?? selectedDay}
        existing={editingEvent}
      />
    </div>
  );
}

function toggleComplete(uid: string, e: CalendarEvent): Promise<void> {
  if (e.type === EventType.appointment) return Promise.resolve();
  const completed = 'isCompleted' in e ? e.isCompleted : false;
  return setEventCompleted(uid, e.id, !completed);
}

/* --------------------------------- views ---------------------------------- */

function AppointmentsView({
  events,
  petName,
  uid,
  onEdit,
}: {
  events: CalendarEvent[];
  petName: Map<string, string>;
  uid: string;
  onEdit: (e: CalendarEvent) => void;
}) {
  const appts = events
    .filter((e) => e.type === EventType.appointment)
    .sort((a, b) => a.dateTime.getTime() - b.dateTime.getTime());
  if (appts.length === 0) {
    return <EmptyState icon={<Stethoscope size={36} />} title="Sem consultas" />;
  }
  const groups = groupByDay(appts, (e) => e.dateTime);
  return (
    <div className="space-y-6">
      {groups.map(([key, list]) => (
        <div key={key}>
          <p className="mb-2 text-sm font-semibold text-muted-foreground">
            {groupFmt.format(list[0]!.dateTime)}
          </p>
          <div className="space-y-2">
            {list.map((e) => (
              <EventRow
                key={e.id}
                event={e}
                petName={e.petId ? petName.get(e.petId) : undefined}
                onEdit={() => onEdit(e)}
                onDelete={() => void deleteEvent(uid, e.id)}
                onToggle={() => {}}
              />
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

function MedicationsView({
  uid,
  meds,
  petName,
}: {
  uid: string;
  meds: Medication[];
  petName: Map<string, string>;
}) {
  if (meds.length === 0) {
    return <EmptyState icon={<Pill size={36} />} title="Sem medicação" description="Adicione medicação na ficha do animal ou no botão Adicionar." />;
  }
  const active = meds.filter(isActive);
  const past = meds.filter((m) => !isActive(m));
  const card = (m: Medication) => (
    <MedicationCard
      key={m.id}
      med={m}
      petName={petName.get(m.petId)}
      onLogDose={() => void logDose(uid, m)}
      onUndo={() => void undoLastDose(uid, m.petId, m.id)}
      onEdit={() => {}}
      onDelete={() => void deleteMedication(uid, m.petId, m.id)}
      onSetStatus={(s: MedicationStatus) => void setMedicationStatus(uid, m.petId, m.id, s)}
    />
  );
  return (
    <div className="space-y-6">
      {active.length > 0 && (
        <Section title="Ativa">{active.map(card)}</Section>
      )}
      {past.length > 0 && <Section title="Passada">{past.map(card)}</Section>}
    </div>
  );
}

function SymptomsView({
  uid,
  symptoms,
  petName,
}: {
  uid: string;
  symptoms: PetSymptom[];
  petName: Map<string, string>;
}) {
  if (symptoms.length === 0) {
    return <EmptyState icon={<Activity size={36} />} title="Sem sintomas" />;
  }
  const groups = groupByDay(symptoms, (s) => s.timestamp);
  return (
    <div className="space-y-6">
      {groups.map(([key, list]) => (
        <div key={key}>
          <p className="mb-2 text-sm font-semibold text-muted-foreground">
            {groupFmt.format(list[0]!.timestamp)}
          </p>
          <div className="space-y-2">
            {list.map((s) => (
              <SymptomRow key={s.id} uid={uid} symptom={s} petName={petName.get(s.petId)} />
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

/* ------------------------------- small parts ------------------------------- */

async function logDose(uid: string, m: Medication): Promise<void> {
  try {
    await logDoseTaken(uid, m.petId, m.id, new Date());
    toast.success('Dose registada');
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Não foi possível registar a dose');
  }
}

function groupByDay<T>(items: T[], getDate: (t: T) => Date): [string, T[]][] {
  const m = new Map<string, T[]>();
  for (const it of items) {
    const k = dayKey(getDate(it));
    (m.get(k) ?? m.set(k, []).get(k)!).push(it);
  }
  return Array.from(m.entries());
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div>
      <p className="mb-2 text-sm font-semibold text-foreground">{title}</p>
      <div className="space-y-2">{children}</div>
    </div>
  );
}

function Dot({ className, selected }: { className: string; selected: boolean }) {
  return <span className={cn('h-1.5 w-1.5 rounded-full', selected ? 'bg-primary-foreground' : className)} />;
}

function EventRow({
  event,
  petName,
  onEdit,
  onDelete,
  onToggle,
}: {
  event: CalendarEvent;
  petName?: string;
  onEdit: () => void;
  onDelete: () => void;
  onToggle: () => void;
}) {
  const completed = event.type !== EventType.appointment && event.isCompleted;
  const color =
    event.type === EventType.appointment ? 'bg-event-appointment' : event.type === EventType.note ? 'bg-accent' : 'bg-event-medication';
  const subtitle =
    event.type === EventType.appointment ? event.location : event.type === EventType.note ? event.category : null;
  return (
    <Card className="p-3">
      <div className="flex items-start gap-3">
        <span className={cn('mt-1.5 h-2.5 w-2.5 shrink-0 rounded-full', color)} />
        <div className="min-w-0 flex-1">
          <p className={cn('font-medium text-foreground', completed && 'line-through opacity-60')}>{event.title}</p>
          <p className="text-xs text-muted-foreground">
            {timeFmt.format(event.dateTime)}
            {petName ? ` · ${petName}` : ''}
            {subtitle ? ` · ${subtitle}` : ''}
          </p>
        </div>
        <div className="flex items-center gap-1">
          {event.type !== EventType.appointment && (
            <button type="button" onClick={onToggle} className={cn('rounded-(--radius-sm) p-1.5 hover:bg-secondary', completed ? 'text-primary' : 'text-muted-foreground')} aria-label="Marcar como feito">
              <Check size={15} />
            </button>
          )}
          {!(event.type === EventType.appointment && event.bookedByVetId) && (
            <>
              <button type="button" onClick={onEdit} className="rounded-(--radius-sm) p-1.5 text-muted-foreground hover:bg-secondary" aria-label="Editar">
                <Pencil size={15} />
              </button>
              <button type="button" onClick={onDelete} className="rounded-(--radius-sm) p-1.5 text-muted-foreground hover:bg-secondary hover:text-destructive" aria-label="Apagar">
                <Trash2 size={15} />
              </button>
            </>
          )}
        </div>
      </div>
    </Card>
  );
}

function SymptomRow({ uid, symptom, petName }: { uid: string; symptom: PetSymptom; petName?: string }) {
  return (
    <Card className="p-3">
      <div className="flex items-start gap-3">
        <span className="mt-1.5 h-2.5 w-2.5 shrink-0 rounded-full bg-event-symptom" />
        <div className="min-w-0 flex-1">
          <p className="font-medium text-foreground">{SYMPTOM_LABELS[symptom.type]}</p>
          <p className="text-xs text-muted-foreground">
            {timeFmt.format(symptom.timestamp)}
            {petName ? ` · ${petName}` : ''}
            {symptom.note ? ` · ${symptom.note}` : ''}
          </p>
        </div>
        <button
          type="button"
          onClick={() => void deleteSymptom(uid, symptom.petId, symptom.id)}
          className="rounded-(--radius-sm) p-1.5 text-muted-foreground hover:bg-secondary hover:text-destructive"
          aria-label="Apagar sintoma"
        >
          <Trash2 size={15} />
        </button>
      </div>
    </Card>
  );
}

function AddChoice({ icon, label, onClick }: { icon: React.ReactNode; label: string; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex items-center gap-3 rounded-(--radius-md) border border-border p-3 text-left transition-colors hover:bg-secondary"
    >
      <span className="flex h-10 w-10 items-center justify-center rounded-(--radius-md) bg-primary-light text-primary">
        {icon}
      </span>
      <span className="font-medium text-foreground">{label}</span>
    </button>
  );
}

function Segmented({
  value,
  onChange,
  options,
}: {
  value: View;
  onChange: (v: View) => void;
  options: { value: View; label: string; icon: typeof CalendarDays }[];
}) {
  return (
    <div className="inline-flex flex-wrap gap-1 rounded-(--radius-pill) border border-border/60 bg-card p-1">
      {options.map((o) => {
        const Icon = o.icon;
        const active = o.value === value;
        return (
          <button
            key={o.value}
            type="button"
            onClick={() => onChange(o.value)}
            className={cn(
              'inline-flex items-center gap-2 rounded-(--radius-pill) px-3.5 py-1.5 text-sm font-medium transition-colors',
              active ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:text-foreground',
            )}
          >
            <Icon size={16} />
            {o.label}
          </button>
        );
      })}
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
