import { useEffect, useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { toast } from 'sonner';
import {
  ArrowLeft,
  Pencil,
  Trash2,
  PawPrint,
  Plus,
  Activity,
  Pill,
} from 'lucide-react';
import {
  SYMPTOM_LABELS,
  EventType,
  type PetSymptom,
  type Medication,
  type MedicationStatus,
} from '@vetplus/shared';
import { useAuth } from '@/auth/AuthProvider';
import {
  petDoc,
  mapPet,
  petAgeLabel,
  symptomsQuery,
  mapSymptom,
  deleteSymptom,
  type Pet,
} from '@/lib/petService';
import {
  medsQuery,
  mapMedication,
  deleteMedication,
  setMedicationStatus,
  logDoseTaken,
  undoLastDose,
} from '@/lib/medicationService';
import {
  eventsQuery,
  mapEvent,
  deleteEvent,
  type CalendarEvent,
} from '@/lib/eventService';
import { useDoc, useCollection } from '@/lib/useFirestore';
import { mapPrivateNotes, privateNotesDoc, savePrivateNotes, type PrivateNotes } from '@/lib/privateNotes';
import { MedicationCard } from '@/features/medications/MedicationCard';
import { MedicationFormDialog } from '@/features/medications/MedicationFormDialog';
import { SymptomFormDialog } from '@/features/symptoms/SymptomFormDialog';
import { EventFormDialog } from '@/features/calendar/EventFormDialog';
import { PageSpinner } from '@/components/Spinner';
import { Card, CardBody } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Dialog } from '@/components/ui/Dialog';
import { Textarea } from '@/components/ui/Textarea';
import { EmptyState } from '@/components/ui/EmptyState';
import { CalendarDays } from 'lucide-react';

const dateFmt = new Intl.DateTimeFormat('pt-PT', {
  month: 'short',
  day: 'numeric',
  year: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
  hourCycle: 'h23',
});

function vetLocked(e: CalendarEvent): boolean {
  return e.type === EventType.appointment && Boolean(e.bookedByVetId);
}

export function PetDetailPage() {
  const { petId, ownerId: ownerParam } = useParams<{ petId: string; ownerId?: string }>();
  const navigate = useNavigate();
  const { firebaseUser, role } = useAuth();
  const uid = ownerParam || firebaseUser?.uid || '';
  const isVetView = role === 'vet' && Boolean(ownerParam);
  const petBase = isVetView ? `/patients/${ownerParam}/pets` : '/pets';

  const ref = useMemo(() => (uid && petId ? petDoc(uid, petId) : null), [uid, petId]);
  const { data: pet, loading } = useDoc<Pet>(ref, mapPet);

  const symQuery = useMemo(
    () => (uid && petId ? symptomsQuery(uid, petId) : null),
    [uid, petId],
  );
  const { data: symptoms } = useCollection<PetSymptom>(symQuery, (id, data) =>
    mapSymptom(uid, petId!, id, data),
  );

  const medQuery = useMemo(
    () => (uid && petId ? medsQuery(uid, petId) : null),
    [uid, petId],
  );
  const { data: meds } = useCollection<Medication>(medQuery, mapMedication);

  const notesRef = useMemo(
    () => (isVetView && uid && petId ? privateNotesDoc(uid, petId) : null),
    [isVetView, uid, petId],
  );
  const { data: privateNotes } = useDoc<PrivateNotes>(notesRef, mapPrivateNotes);
  const [notesDraft, setNotesDraft] = useState('');
  const [savingNotes, setSavingNotes] = useState(false);
  useEffect(() => {
    if (privateNotes) setNotesDraft(privateNotes.text);
  }, [privateNotes]);

  const eventQuery = useMemo(() => (uid ? eventsQuery(uid) : null), [uid]);
  const { data: allEvents } = useCollection<CalendarEvent>(eventQuery, mapEvent);
  const petEvents = useMemo(
    () =>
      allEvents
        .filter((e) => e.petId === petId && e.type !== EventType.medication)
        .sort((a, b) => b.dateTime.getTime() - a.dateTime.getTime())
        .slice(0, 5),
    [allEvents, petId],
  );

  const [logOpen, setLogOpen] = useState(false);
  const [medFormOpen, setMedFormOpen] = useState(false);
  const [editingMed, setEditingMed] = useState<Medication | null>(null);
  const [deleteMed, setDeleteMed] = useState<Medication | null>(null);
  const [apptFormOpen, setApptFormOpen] = useState(false);
  const [editingEvent, setEditingEvent] = useState<CalendarEvent | null>(null);

  if (loading) return <PageSpinner />;
  if (!pet) {
    return (
      <EmptyState
        icon={<PawPrint size={40} />}
        title="Animal não encontrado"
        action={<Button onClick={() => navigate(isVetView ? `/patients/${ownerParam}` : '/pets')}>Voltar</Button>}
      />
    );
  }

  const onLogDose = async (m: Medication) => {
    try {
      await logDoseTaken(uid, pet.id, m.id, new Date());
      toast.success('Dose registada');
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Não foi possível registar a dose');
    }
  };

  const onUndoDose = async (m: Medication) => {
    const ok = await undoLastDose(uid, pet.id, m.id);
    toast[ok ? 'success' : 'message'](ok ? 'Última dose anulada' : 'Sem dose para anular');
  };

  const onSetStatus = async (m: Medication, status: MedicationStatus) => {
    try {
      await setMedicationStatus(uid, pet.id, m.id, status);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Não foi possível atualizar a medicação');
    }
  };

  const onDeleteMed = async (m: Medication) => {
    try {
      await deleteMedication(uid, pet.id, m.id);
      toast.success('Medicação apagada');
      setDeleteMed(null);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Não foi possível apagar a medicação');
    }
  };

  return (
    <div className="mx-auto max-w-3xl">
      <button
        type="button"
        onClick={() => navigate(isVetView ? `/patients/${ownerParam}` : '/pets')}
        className="mb-4 inline-flex items-center gap-1.5 text-sm font-medium text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft size={16} /> Animais
      </button>

      {/* Header */}
      <div className="mb-6 flex flex-wrap items-center gap-4">
        <div className="flex h-20 w-20 items-center justify-center overflow-hidden rounded-(--radius-lg) bg-primary-light">
          {pet.photoUrl ? (
            <img src={pet.photoUrl} alt={pet.name} className="h-full w-full object-cover" />
          ) : (
            <PawPrint size={36} className="text-primary" />
          )}
        </div>
        <div className="min-w-0 flex-1">
          <h1 className="font-display text-3xl font-bold text-foreground">{pet.name}</h1>
          <p className="text-muted-foreground">
            {[pet.species, pet.breed].filter(Boolean).join(' · ') || 'Animal'} ·{' '}
            {petAgeLabel(pet.dateOfBirth)}
          </p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" onClick={() => navigate(`${petBase}/${pet.id}/edit`)}>
            <Pencil size={16} /> Editar
          </Button>
        </div>
      </div>

      {isVetView && petId && (
        <Card className="mb-6">
          <CardBody className="space-y-3">
            <p className="text-sm font-semibold text-foreground">Notas privadas</p>
            <p className="text-xs text-muted-foreground">
              Só a veterinária vê estas notas. O cliente não.
            </p>
            <Textarea
              label="Notas"
              value={notesDraft}
              onChange={(e) => setNotesDraft(e.target.value)}
            />
            <div className="flex justify-end">
              <Button
                loading={savingNotes}
                onClick={() => {
                  setSavingNotes(true);
                  void savePrivateNotes({
                    clientId: uid,
                    petId,
                    text: notesDraft,
                    vetId: firebaseUser?.uid ?? '',
                  })
                    .then(() => toast.success('Notas guardadas'))
                    .catch((e) => toast.error(e instanceof Error ? e.message : 'Não foi possível guardar'))
                    .finally(() => setSavingNotes(false));
                }}
              >
                Guardar notas
              </Button>
            </div>
          </CardBody>
        </Card>
      )}

      {/* Info */}
      <Card className="mb-6">
        <CardBody>
          <p className="mb-4 text-sm font-semibold text-foreground">Ficha</p>
          <dl className="grid grid-cols-1 gap-x-8 gap-y-3 sm:grid-cols-2">
            <Detail
              label="Sexo"
              value={
                pet.gender === 'Male' ? 'Macho' : pet.gender === 'Female' ? 'Fêmea' : 'Desconhecido'
              }
            />
            <Detail
              label="Data de nascimento"
              value={
                pet.dateOfBirth
                  ? pet.dateOfBirth.toLocaleDateString('pt-PT', {
                      year: 'numeric',
                      month: 'long',
                      day: 'numeric',
                    })
                  : '—'
              }
            />
            <Detail label="Peso" value={pet.weight || '—'} />
            <Detail label="Cor / marcas" value={pet.color || '—'} />
            <Detail label="Microchip" value={pet.microchip || '—'} />
          </dl>
        </CardBody>
      </Card>

      {/* Medications */}
      <div className="mb-3 flex items-center justify-between">
        <h2 className="font-display text-xl font-bold text-foreground">Medicação</h2>
        <Button
          variant="outline"
          onClick={() => {
            setEditingMed(null);
            setMedFormOpen(true);
          }}
        >
          <Plus size={16} /> Adicionar medicação
        </Button>
      </div>

      {meds.length === 0 ? (
        <EmptyState
          icon={<Pill size={36} />}
          title="Sem medicação"
          description="Adicione medicação para seguir doses e lembretes."
        />
      ) : (
        <div className="space-y-3">
          {meds.map((m) => (
            <MedicationCard
              key={m.id}
              med={m}
              onLogDose={() => void onLogDose(m)}
              onUndo={() => void onUndoDose(m)}
              onEdit={() => {
                setEditingMed(m);
                setMedFormOpen(true);
              }}
              onDelete={() => setDeleteMed(m)}
              onSetStatus={(s) => void onSetStatus(m, s)}
            />
          ))}
        </div>
      )}

      {/* Appointments */}
      <div className="mb-3 mt-8 flex items-center justify-between">
        <h2 className="font-display text-xl font-bold text-foreground">Consultas</h2>
        <Button
          variant="outline"
          onClick={() => {
            setEditingEvent(null);
            setApptFormOpen(true);
          }}
        >
          <Plus size={16} /> Adicionar consulta
        </Button>
      </div>

      {petEvents.length === 0 ? (
        <EmptyState
          icon={<CalendarDays size={36} />}
          title="Sem consultas"
          description="Adicione uma consulta para ter a agenda deste animal num só sítio."
        />
      ) : (
        <Card>
          <ul className="divide-y divide-border">
            {petEvents.map((e) => (
              <li key={e.id} className="flex items-start gap-3 p-4">
                <span
                  className={
                    'mt-1.5 h-2 w-2 shrink-0 rounded-full ' +
                    (e.type === EventType.appointment ? 'bg-event-appointment' : 'bg-accent')
                  }
                />
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-medium text-foreground">{e.title}</p>
                  <p className="text-xs text-muted-foreground">{dateFmt.format(e.dateTime)}</p>
                </div>
                {(isVetView || !vetLocked(e)) && (
                  <>
                    <button
                      type="button"
                      onClick={() => {
                        setEditingEvent(e);
                        setApptFormOpen(true);
                      }}
                      className="shrink-0 rounded-(--radius-sm) p-1.5 text-muted-foreground hover:bg-secondary"
                      aria-label="Editar marcação"
                    >
                      <Pencil size={15} />
                    </button>
                    <button
                      type="button"
                      onClick={() => void deleteEvent(uid, e.id)}
                      className="shrink-0 rounded-(--radius-sm) p-1.5 text-muted-foreground hover:bg-secondary hover:text-destructive"
                      aria-label="Apagar marcação"
                    >
                      <Trash2 size={15} />
                    </button>
                  </>
                )}
              </li>
            ))}
          </ul>
        </Card>
      )}

      {/* Symptoms */}
      <div className="mb-3 mt-8 flex items-center justify-between">
        <h2 className="font-display text-xl font-bold text-foreground">Sintomas</h2>
        <Button variant="outline" onClick={() => setLogOpen(true)}>
          <Plus size={16} /> Registar sintoma
        </Button>
      </div>

      {symptoms.length === 0 ? (
        <EmptyState
          icon={<Activity size={36} />}
          title="Sem sintomas registados"
          description="Registe sintomas para partilhar o histórico com a veterinária."
        />
      ) : (
        <Card>
          <ul className="divide-y divide-border">
            {symptoms.map((s) => (
              <li key={s.id} className="flex items-start gap-3 p-4">
                <div className="mt-1.5 h-2 w-2 shrink-0 rounded-full bg-event-symptom" />
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-medium text-foreground">
                    {SYMPTOM_LABELS[s.type]}
                  </p>
                  <p className="text-xs text-muted-foreground">{dateFmt.format(s.timestamp)}</p>
                  {s.note && (
                    <p className="mt-1 text-sm text-muted-foreground">{s.note}</p>
                  )}
                </div>
                <button
                  type="button"
                  onClick={() => void deleteSymptom(uid, pet.id, s.id)}
                  className="shrink-0 rounded-(--radius-sm) p-1.5 text-muted-foreground hover:bg-secondary hover:text-destructive"
                  aria-label="Apagar sintoma"
                >
                  <Trash2 size={15} />
                </button>
              </li>
            ))}
          </ul>
        </Card>
      )}

      <SymptomFormDialog
        open={logOpen}
        onClose={() => setLogOpen(false)}
        uid={uid}
        petId={pet.id}
        petName={pet.name}
      />

      <EventFormDialog
        open={apptFormOpen}
        onClose={() => {
          setApptFormOpen(false);
          setEditingEvent(null);
        }}
        uid={uid}
        pets={[pet]}
        defaultDate={editingEvent?.dateTime ?? new Date()}
        existing={editingEvent}
        lockToAppointment={!editingEvent}
        presetPetId={pet.id}
      />

      <MedicationFormDialog
        open={medFormOpen}
        onClose={() => setMedFormOpen(false)}
        uid={uid}
        petId={pet.id}
        existing={editingMed}
      />

      <Dialog
        open={Boolean(deleteMed)}
        onClose={() => setDeleteMed(null)}
        title="Apagar medicação"
        description={
          deleteMed ? `Apagar ${deleteMed.name}? Não dá para desfazer.` : ''
        }
        footer={
          <>
            <Button variant="outline" onClick={() => setDeleteMed(null)}>
              Cancelar
            </Button>
            <Button
              variant="destructive"
              onClick={() => deleteMed && void onDeleteMed(deleteMed)}
            >
              Apagar
            </Button>
          </>
        }
      />
    </div>
  );
}

function Detail({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
        {label}
      </dt>
      <dd className="mt-0.5 text-sm text-foreground">{value}</dd>
    </div>
  );
}

