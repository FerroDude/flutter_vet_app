import { useMemo, useState, type ReactNode } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { toast } from 'sonner';
import { Activity, ArrowLeft, CalendarDays, PawPrint, Pencil, Pill, Plus, Trash2 } from 'lucide-react';
import { PetAvatar } from '@/components/ui/PetAvatar';
import { SYMPTOM_LABELS, EventType, type PetSymptom, type Medication } from '@vetplus/shared';
import { useAuth } from '@/auth/AuthProvider';
import { useDoc, useCollection } from '@/lib/useFirestore';
import { petDoc, mapPet, petAgeLabel, symptomsQuery, mapSymptom, deleteSymptom, type Pet } from '@/lib/petService';
import {
  medsQuery,
  mapMedication,
  deleteMedication,
  setMedicationStatus,
  logDoseTaken,
  undoLastDose,
} from '@/lib/medicationService';
import { eventsQuery, mapEvent, deleteEvent, isCancelled, type AppointmentEvent, type CalendarEvent } from '@/lib/eventService';
import { clientLabel } from '@/lib/clientService';
import { dateTimeFmt, errorMessage, longDateFmt } from '@/lib/format';
import { cn } from '@/lib/cn';
import { PageSpinner } from '@/components/Spinner';
import { Card, CardBody } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { EmptyState } from '@/components/ui/EmptyState';
import { useConfirm } from '@/components/ui/Confirm';
import { MedicationCard } from '@/features/medications/MedicationCard';
import { MedicationFormDialog } from '@/features/medications/MedicationFormDialog';
import { SymptomFormDialog } from '@/features/symptoms/SymptomFormDialog';
import { EventFormDialog } from '@/features/calendar/EventFormDialog';
import { RequestFormDialog } from '@/features/calendar/RequestFormDialog';
import { VetAppointmentDialog } from '@/features/vet/VetAppointmentDialog';
import { PrivateNotesCard } from './PrivateNotesCard';

/**
 * One pet's record. Clients see their own pets at /pets/:petId; the vet sees a
 * client's pet at /clients/:ownerId/pets/:petId and also gets private notes
 * and books appointments directly.
 */
export function PetDetailPage() {
  const { petId = '', ownerId } = useParams<{ petId: string; ownerId?: string }>();
  const navigate = useNavigate();
  const confirm = useConfirm();
  const { firebaseUser, profile, role } = useAuth();
  const isVetView = role === 'vet' && Boolean(ownerId);
  const uid = (isVetView ? ownerId : firebaseUser?.uid) ?? '';
  const back = isVetView ? `/clients/${ownerId}` : '/pets';
  const vetName = profile?.displayName?.trim() || 'Veterinária';

  const ref = useMemo(() => (uid && petId ? petDoc(uid, petId) : null), [uid, petId]);
  const { data: pet, loading } = useDoc<Pet>(ref, mapPet);

  const sq = useMemo(() => (uid && petId ? symptomsQuery(uid, petId) : null), [uid, petId]);
  const { data: symptoms } = useCollection<PetSymptom>(sq, (id, d) => mapSymptom(uid, petId, id, d));

  const mq = useMemo(() => (uid && petId ? medsQuery(uid, petId) : null), [uid, petId]);
  const { data: meds } = useCollection<Medication>(mq, mapMedication);

  const eq = useMemo(() => (uid ? eventsQuery(uid) : null), [uid]);
  const { data: allEvents } = useCollection<CalendarEvent>(eq, mapEvent);
  const petEvents = useMemo(
    () =>
      allEvents
        .filter((e) => e.petId === petId && e.type !== EventType.medication)
        .sort((a, b) => b.dateTime.getTime() - a.dateTime.getTime())
        .slice(0, 5),
    [allEvents, petId],
  );

  const [symptomOpen, setSymptomOpen] = useState(false);
  const [medForm, setMedForm] = useState<{ existing: Medication | null } | null>(null);
  const [apptOpen, setApptOpen] = useState(false);
  const [editingEvent, setEditingEvent] = useState<CalendarEvent | null>(null);

  if (loading) return <PageSpinner />;
  if (!pet) {
    return (
      <EmptyState
        icon={<PawPrint size={40} />}
        title="Animal não encontrado"
        action={<Button onClick={() => navigate(back)}>Voltar</Button>}
      />
    );
  }

  const run = (p: Promise<unknown>, ok?: string) =>
    p.then(() => ok && toast.success(ok)).catch((e) => toast.error(errorMessage(e)));

  const remove = async (what: string, action: () => Promise<unknown>) => {
    if (await confirm({ title: 'Apagar?', description: `Apagar ${what}? Não dá para desfazer.`, confirmLabel: 'Apagar', danger: true })) {
      void run(action(), 'Apagado');
    }
  };

  /** Vet edits any appointment for this client; clients only their own entries. */
  const canEdit = (e: CalendarEvent) =>
    isVetView || !(e.type === EventType.appointment && e.bookedByVetId);

  return (
    <div className="mx-auto max-w-3xl">
      <button
        type="button"
        onClick={() => navigate(back)}
        className="mb-4 inline-flex items-center gap-1.5 text-sm font-medium text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft size={16} /> {isVetView ? 'Cliente' : 'Animais'}
      </button>

      <div className="mb-6 flex flex-wrap items-center gap-4">
        <PetAvatar pet={pet} size={88} />
        <div className="min-w-0 flex-1">
          <h1 className="break-words font-display text-3xl font-bold text-foreground">{pet.name}</h1>
          <p className="text-muted-foreground">
            {[pet.species, pet.breed].filter(Boolean).join(' · ') || 'Animal'} · {petAgeLabel(pet.dateOfBirth)}
          </p>
        </div>
        <Button variant="outline" onClick={() => navigate(`${isVetView ? `/clients/${ownerId}/pets` : '/pets'}/${pet.id}/edit`)}>
          <Pencil size={16} /> Editar
        </Button>
      </div>

      {isVetView && <PrivateNotesCard clientId={uid} petId={petId} vetId={firebaseUser?.uid ?? ''} />}

      <Card className="mb-8">
        <CardBody>
          <p className="mb-4 text-sm font-semibold text-foreground">Ficha</p>
          <dl className="grid grid-cols-1 gap-x-8 gap-y-3 sm:grid-cols-2">
            <Detail label="Sexo" value={pet.gender === 'Male' ? 'Macho' : pet.gender === 'Female' ? 'Fêmea' : '—'} />
            <Detail label="Data de nascimento" value={pet.dateOfBirth ? longDateFmt.format(pet.dateOfBirth) : '—'} />
            <Detail label="Peso" value={pet.weight || '—'} />
            <Detail label="Cor / marcas" value={pet.color || '—'} />
            <Detail label="Microchip" value={pet.microchip || '—'} />
          </dl>
          {pet.medicalNotes && (
            <div className="mt-4 border-t border-border pt-4">
              <Detail label="Notas de saúde" value={pet.medicalNotes} />
            </div>
          )}
        </CardBody>
      </Card>

      <Section
        title="Medicação"
        action={
          <Button variant="outline" onClick={() => setMedForm({ existing: null })}>
            <Plus size={16} /> Adicionar
          </Button>
        }
      >
        {meds.length === 0 ? (
          <EmptyState icon={<Pill size={36} />} title="Sem medicação" />
        ) : (
          <div className="space-y-3">
            {meds.map((m) => (
              <MedicationCard
                key={m.id}
                med={m}
                onLogDose={() => void run(logDoseTaken(uid, pet.id, m.id, new Date()), 'Dose registada')}
                onUndo={() =>
                  void undoLastDose(uid, pet.id, m.id).then((ok) =>
                    toast[ok ? 'success' : 'message'](ok ? 'Última dose anulada' : 'Sem dose para anular'),
                  )
                }
                onEdit={() => setMedForm({ existing: m })}
                onDelete={() => void remove(m.name, () => deleteMedication(uid, pet.id, m.id))}
                onSetStatus={(s) => void run(setMedicationStatus(uid, pet.id, m.id, s))}
              />
            ))}
          </div>
        )}
      </Section>

      <Section
        title="Consultas"
        action={
          isVetView || profile?.vetId ? (
            <Button
              variant="outline"
              onClick={() => {
                setEditingEvent(null);
                setApptOpen(true);
              }}
            >
              <Plus size={16} /> {isVetView ? 'Marcar consulta' : 'Pedir marcação'}
            </Button>
          ) : undefined
        }
      >
        {petEvents.length === 0 ? (
          <EmptyState icon={<CalendarDays size={36} />} title="Sem consultas" />
        ) : (
          <Card>
            <ul className="divide-y divide-border">
              {petEvents.map((e) => (
                <ListRow
                  key={e.id}
                  to={!isVetView && e.type === EventType.appointment ? `/agenda/consultas/${e.id}` : undefined}
                  strike={isCancelled(e)}
                  dot={e.type === EventType.appointment ? 'bg-event-appointment' : 'bg-accent'}
                  title={e.title}
                  meta={`${dateTimeFmt.format(e.dateTime)}${isCancelled(e) ? ' · Cancelada' : ''}`}
                  actions={
                    canEdit(e) && (
                      <>
                        <IconBtn
                          label="Editar"
                          onClick={() => {
                            setEditingEvent(e);
                            setApptOpen(true);
                          }}
                        >
                          <Pencil size={15} />
                        </IconBtn>
                        <IconBtn label="Apagar" danger onClick={() => void remove(`"${e.title}"`, () => deleteEvent(uid, e.id))}>
                          <Trash2 size={15} />
                        </IconBtn>
                      </>
                    )
                  }
                />
              ))}
            </ul>
          </Card>
        )}
      </Section>

      <Section
        title="Sintomas"
        action={
          <Button variant="outline" onClick={() => setSymptomOpen(true)}>
            <Plus size={16} /> Registar
          </Button>
        }
      >
        {symptoms.length === 0 ? (
          <EmptyState
            icon={<Activity size={36} />}
            title="Sem sintomas registados"
            description={isVetView ? undefined : 'Registe sintomas para a veterinária ver o histórico.'}
          />
        ) : (
          <Card>
            <ul className="divide-y divide-border">
              {symptoms.map((s) => (
                <ListRow
                  key={s.id}
                  dot="bg-event-symptom"
                  title={SYMPTOM_LABELS[s.type]}
                  meta={dateTimeFmt.format(s.timestamp)}
                  note={s.note}
                  actions={
                    <IconBtn
                      label="Apagar sintoma"
                      danger
                      onClick={() => void remove('este sintoma', () => deleteSymptom(uid, pet.id, s.id))}
                    >
                      <Trash2 size={15} />
                    </IconBtn>
                  }
                />
              ))}
            </ul>
          </Card>
        )}
      </Section>

      <SymptomFormDialog open={symptomOpen} onClose={() => setSymptomOpen(false)} uid={uid} petId={pet.id} petName={pet.name} />
      <MedicationFormDialog
        open={medForm !== null}
        onClose={() => setMedForm(null)}
        uid={uid}
        petId={pet.id}
        existing={medForm?.existing ?? null}
      />

      {isVetView ? (
        <VetAppointmentDialog
          open={apptOpen}
          onClose={() => {
            setApptOpen(false);
            setEditingEvent(null);
          }}
          vetId={firebaseUser?.uid ?? ''}
          vetName={vetName}
          defaultDay={new Date()}
          presetClientId={uid}
          presetPetId={pet.id}
          existing={editingEvent?.type === EventType.appointment ? (editingEvent as AppointmentEvent) : null}
        />
      ) : editingEvent ? (
        <EventFormDialog
          open={apptOpen}
          onClose={() => {
            setApptOpen(false);
            setEditingEvent(null);
          }}
          uid={uid}
          pets={[pet]}
          defaultDate={editingEvent.dateTime}
          existing={editingEvent}
        />
      ) : (
        profile?.vetId && (
          <RequestFormDialog
            open={apptOpen}
            onClose={() => setApptOpen(false)}
            vetId={profile.vetId}
            petOwnerId={uid}
            petOwnerName={profile ? clientLabel(profile) : ''}
            pets={[pet]}
          />
        )
      )}
    </div>
  );
}

function Section({ title, action, children }: { title: string; action?: ReactNode; children: ReactNode }) {
  return (
    <section className="mb-8">
      <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
        <h2 className="font-display text-xl font-bold text-foreground">{title}</h2>
        {action}
      </div>
      {children}
    </section>
  );
}

function ListRow({
  dot,
  title,
  meta,
  note,
  actions,
  strike,
  to,
}: {
  dot: string;
  title: string;
  meta: string;
  note?: string | null;
  actions?: ReactNode;
  strike?: boolean;
  to?: string;
}) {
  const content = (
    <>
      <span className={cn('mt-1.5 h-2 w-2 shrink-0 rounded-full', dot)} />
      <div className="min-w-0 flex-1">
        <p className={cn('break-words text-sm font-medium text-foreground', strike && 'line-through opacity-60')}>
          {title}
        </p>
        <p className="text-xs text-muted-foreground">{meta}</p>
        {note && <p className="mt-1 whitespace-pre-wrap break-words text-sm text-muted-foreground">{note}</p>}
      </div>
    </>
  );
  return (
    <li className="flex items-start gap-3 p-4">
      {to ? (
        <Link to={to} className="flex min-w-0 flex-1 items-start gap-3">
          {content}
        </Link>
      ) : (
        content
      )}
      {actions && <div className="flex shrink-0 items-center gap-1">{actions}</div>}
    </li>
  );
}

function IconBtn({
  children,
  label,
  onClick,
  danger,
}: {
  children: ReactNode;
  label: string;
  onClick: () => void;
  danger?: boolean;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      className={cn(
        'rounded-(--radius-sm) p-1.5 text-muted-foreground hover:bg-secondary',
        danger && 'hover:text-destructive',
      )}
    >
      {children}
    </button>
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
