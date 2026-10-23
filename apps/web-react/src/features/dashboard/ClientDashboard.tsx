import { useMemo } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { toast } from 'sonner';
import { CalendarDays, ChevronRight, MessageCircle, PawPrint, Plus } from 'lucide-react';
import { EventType, isActive, nextDose, type MedicationStatus } from '@vetplus/shared';
import { useAuth } from '@/auth/AuthProvider';
import { useCollection } from '@/lib/useFirestore';
import { petsQuery, mapPet, petAgeLabel, type Pet } from '@/lib/petService';
import { eventsQuery, mapEvent, type CalendarEvent } from '@/lib/eventService';
import { useRooms } from '@/lib/chatService';
import { logDoseTaken, undoLastDose, setMedicationStatus } from '@/lib/medicationService';
import { useAllMedications } from '@/lib/useAllMedications';
import { dateTimeFmt, dayHeadFmt, errorMessage, greeting, sameDay, timeFmt } from '@/lib/format';
import { chatRoomPath } from '@/features/chat/useSelectedChatRoom';
import { Card } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { EmptyState } from '@/components/ui/EmptyState';
import { MedicationCard } from '@/features/medications/MedicationCard';

export function ClientDashboard() {
  const { firebaseUser, profile } = useAuth();
  const navigate = useNavigate();
  const uid = firebaseUser?.uid ?? '';

  const pq = useMemo(() => (uid ? petsQuery(uid) : null), [uid]);
  const { data: pets } = useCollection<Pet>(pq, mapPet);
  const petName = useMemo(() => new Map(pets.map((p) => [p.id, p.name])), [pets]);

  const eq = useMemo(() => (uid ? eventsQuery(uid) : null), [uid]);
  const { data: events } = useCollection<CalendarEvent>(eq, mapEvent);
  const todayEvents = events.filter((e) => e.type !== EventType.medication && sameDay(e.dateTime, new Date()));
  const upcoming = events
    .filter((e) => e.type === EventType.appointment && e.dateTime.getTime() >= Date.now())
    .slice(0, 3);

  const { rooms, unread } = useRooms('petOwnerId', uid);
  const meds = useAllMedications(uid);
  const activeMeds = useMemo(
    () =>
      meds
        .filter(isActive)
        .sort((a, b) => (nextDose(a)?.getTime() ?? Infinity) - (nextDose(b)?.getTime() ?? Infinity)),
    [meds],
  );

  const firstName = (profile?.displayName ?? '').trim().split(' ')[0];
  const run = (p: Promise<unknown>, ok?: string) =>
    p.then(() => ok && toast.success(ok)).catch((e) => toast.error(errorMessage(e)));

  return (
    <div className="space-y-10">
      <SectionHeader
        as="h1"
        eyebrow={dayHeadFmt.format(new Date())}
        title={firstName ? `${greeting()}, ${firstName}` : greeting()}
      />

      {unread > 0 && (
        <Banner
          icon={<MessageCircle size={20} />}
          title={unread === 1 ? '1 mensagem por ler' : `${unread} mensagens por ler`}
          subtitle="Da sua veterinária."
          onClick={() => navigate(rooms[0] ? chatRoomPath(rooms[0].id) : '/chat')}
        />
      )}

      <section>
        <SectionHeader
          className="mb-4"
          eyebrow="Os seus animais"
          title="Animais"
          action={
            <Button variant="ghost" onClick={() => navigate('/pets/new')}>
              <Plus size={16} /> Adicionar animal
            </Button>
          }
        />
        {pets.length === 0 ? (
          <EmptyState
            icon={<PawPrint size={36} />}
            title="Ainda sem animais"
            description="Adicione o primeiro animal para começar."
            action={<Button onClick={() => navigate('/pets/new')}>Adicionar animal</Button>}
          />
        ) : (
          <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4">
            {pets.map((pet) => (
              <Link key={pet.id} to={`/pets/${pet.id}`} className="group">
                <Card className="overflow-hidden transition-[transform,box-shadow] group-hover:-translate-y-0.5 group-hover:shadow-(--shadow-md)">
                  <div className="flex h-24 items-center justify-center bg-primary-light">
                    {pet.photoUrl ? (
                      <img src={pet.photoUrl} alt={pet.name} className="h-full w-full object-cover" />
                    ) : (
                      <span className="font-display text-4xl font-semibold leading-none text-primary/70">
                        {pet.name.charAt(0).toUpperCase() || '?'}
                      </span>
                    )}
                  </div>
                  <div className="p-3 text-center">
                    <p className="truncate font-medium text-foreground">{pet.name}</p>
                    <p className="text-xs text-muted-foreground">{petAgeLabel(pet.dateOfBirth)}</p>
                  </div>
                </Card>
              </Link>
            ))}
          </div>
        )}
      </section>

      {upcoming.length > 0 && (
        <section>
          <SectionHeader
            className="mb-4"
            eyebrow="Agenda"
            title="Próximas consultas"
            action={
              <Button variant="ghost" onClick={() => navigate('/agenda')}>
                Ver agenda
              </Button>
            }
          />
          <div className="space-y-2">
            {upcoming.map((e) => (
              <Link key={e.id} to="/agenda" className="block">
                <Card className="flex items-center gap-3 p-3 transition-colors hover:bg-secondary">
                  <span className="h-2.5 w-2.5 shrink-0 rounded-full bg-event-appointment" />
                  <span className="min-w-0 flex-1">
                    <span className="block truncate font-medium text-foreground">{e.title}</span>
                    <span className="block truncate text-xs text-muted-foreground">
                      {[
                        dateTimeFmt.format(e.dateTime),
                        e.petId ? petName.get(e.petId) : null,
                        e.type === EventType.appointment ? e.location : null,
                      ]
                        .filter(Boolean)
                        .join(' · ')}
                    </span>
                  </span>
                  <ChevronRight size={16} className="shrink-0 text-muted-foreground" />
                </Card>
              </Link>
            ))}
          </div>
        </section>
      )}

      {activeMeds.length > 0 && (
        <section>
          <SectionHeader className="mb-4" eyebrow="Plano" title="Medicação ativa" />
          <div className="space-y-3">
            {activeMeds.slice(0, 3).map((m) => (
              <MedicationCard
                key={m.id}
                med={m}
                petName={petName.get(m.petId)}
                onLogDose={() => void run(logDoseTaken(uid, m.petId, m.id, new Date()), 'Dose registada')}
                onUndo={() => void run(undoLastDose(uid, m.petId, m.id))}
                onEdit={() => navigate(`/pets/${m.petId}`)}
                onDelete={() => navigate(`/pets/${m.petId}`)}
                onSetStatus={(s: MedicationStatus) => void run(setMedicationStatus(uid, m.petId, m.id, s))}
              />
            ))}
            {activeMeds.length > 3 && (
              <p className="text-center text-sm text-muted-foreground">
                +{activeMeds.length - 3} {activeMeds.length - 3 === 1 ? 'outra medicação' : 'outras medicações'} nas
                fichas dos animais
              </p>
            )}
          </div>
        </section>
      )}

      <section>
        <SectionHeader className="mb-4" eyebrow="Agenda" title="Hoje" />
        {todayEvents.length === 0 ? (
          <Card className="flex items-center gap-3 p-4">
            <CalendarDays size={20} className="text-muted-foreground" />
            <p className="text-sm text-muted-foreground">Nada marcado para hoje.</p>
          </Card>
        ) : (
          <div className="space-y-2">
            {todayEvents.map((e) => (
              <Link key={e.id} to="/agenda" className="block">
                <Card className="flex items-center gap-3 p-3 transition-colors hover:bg-secondary">
                  <span className="shrink-0 text-xs font-medium tabular-nums text-muted-foreground">
                    {timeFmt.format(e.dateTime)}
                  </span>
                  <span className="min-w-0 flex-1 truncate">
                    <span className="font-medium text-foreground">{e.title}</span>
                    {e.petId && petName.get(e.petId) && (
                      <span className="text-xs text-muted-foreground"> · {petName.get(e.petId)}</span>
                    )}
                  </span>
                  <ChevronRight size={16} className="shrink-0 text-muted-foreground" />
                </Card>
              </Link>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}

function Banner({
  icon,
  title,
  subtitle,
  onClick,
}: {
  icon: React.ReactNode;
  title: string;
  subtitle: string;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex w-full items-center gap-3 rounded-(--radius-lg) border border-border bg-primary-light p-4 text-left transition-colors hover:bg-primary-light/70"
    >
      <span className="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-primary text-primary-foreground">
        {icon}
      </span>
      <span className="min-w-0 flex-1">
        <span className="block font-medium text-foreground">{title}</span>
        <span className="block truncate text-sm text-muted-foreground">{subtitle}</span>
      </span>
      <ChevronRight size={18} className="shrink-0 text-muted-foreground" />
    </button>
  );
}
