import { useMemo } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { PawPrint, Plus, CalendarDays, MessageCircle, ChevronRight } from 'lucide-react';
import {
  isActive,
  nextDose,
  type MedicationStatus,
  type Medication,
  type ChatRoom,
} from '@vetplus/shared';
import { useAuth } from '@/auth/AuthProvider';
import { petsQuery, mapPet, petAgeLabel, type Pet } from '@/lib/petService';
import {
  eventsQuery,
  mapEvent,
  type CalendarEvent,
} from '@/lib/eventService';
import { petOwnerRoomsQuery, mapRoom } from '@/lib/chatService';
import { chatRoomPath } from '@/features/chat/useSelectedChatRoom';
import {
  logDoseTaken,
  undoLastDose,
  setMedicationStatus,
} from '@/lib/medicationService';
import { useAllMedications } from '@/lib/useAllMedications';
import { useCollection } from '@/lib/useFirestore';
import { Card } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { EmptyState } from '@/components/ui/EmptyState';
import { MedicationCard } from '@/features/medications/MedicationCard';
import { toast } from 'sonner';

const timeFmt = new Intl.DateTimeFormat('pt-PT', { hour: 'numeric', minute: '2-digit' });

function isToday(d: Date): boolean {
  const n = new Date();
  return d.getFullYear() === n.getFullYear() && d.getMonth() === n.getMonth() && d.getDate() === n.getDate();
}

export function PetOwnerDashboard() {
  const { firebaseUser, profile } = useAuth();
  const navigate = useNavigate();
  const uid = firebaseUser?.uid ?? '';

  const petQ = useMemo(() => (uid ? petsQuery(uid) : null), [uid]);
  const { data: pets } = useCollection<Pet>(petQ, mapPet);

  const eventQ = useMemo(() => (uid ? eventsQuery(uid) : null), [uid]);
  const { data: events } = useCollection<CalendarEvent>(eventQ, mapEvent);

  const roomsQ = useMemo(() => (uid ? petOwnerRoomsQuery(uid) : null), [uid]);
  const { data: rooms } = useCollection<ChatRoom>(roomsQ, mapRoom);
  const unreadRooms = useMemo(
    () =>
      rooms
        .filter((r) => r.isActive && (r.unreadCounts[uid] ?? 0) > 0)
        .sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime()),
    [rooms, uid],
  );
  const unreadTotal = useMemo(
    () => unreadRooms.reduce((sum, r) => sum + (r.unreadCounts[uid] ?? 0), 0),
    [unreadRooms, uid],
  );

  const allMeds = useAllMedications(uid);
  const activeMeds = useMemo(
    () =>
      allMeds
        .filter(isActive)
        .sort((a, b) => {
          const an = nextDose(a)?.getTime() ?? Infinity;
          const bn = nextDose(b)?.getTime() ?? Infinity;
          return an - bn;
        }),
    [allMeds],
  );

  const petNames = useMemo(() => {
    const m = new Map<string, string>();
    pets.forEach((p) => m.set(p.id, p.name));
    return m;
  }, [pets]);

  const todayEvents = useMemo(
    () =>
      events
        .filter((e) => isToday(e.dateTime))
        .sort((a, b) => a.dateTime.getTime() - b.dateTime.getTime()),
    [events],
  );

  const firstName = (profile?.displayName ?? '').trim().split(' ')[0] ?? '';
  const hour = new Date().getHours();
  const greeting = hour < 12 ? 'Bom dia' : hour < 18 ? 'Boa tarde' : 'Boa noite';
  const dateLabel = new Intl.DateTimeFormat('pt-PT', {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
  }).format(new Date());

  const onLog = async (m: Medication) => {
    try {
      await logDoseTaken(uid, m.petId, m.id, new Date());
      toast.success('Dose registada');
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Não foi possível registar a dose');
    }
  };

  return (
    <div className="space-y-10">
      <SectionHeader
        as="h1"
        eyebrow={dateLabel}
        title={firstName ? `${greeting}, ${firstName}` : greeting}
      />

      {/* Unread messages */}
      {unreadTotal > 0 && (
        <button
          type="button"
          onClick={() => navigate(unreadRooms[0] ? chatRoomPath(unreadRooms[0].id) : '/chat')}
          className="flex w-full items-center gap-3 rounded-(--radius-lg) border border-border bg-primary-light p-4 text-left transition-colors hover:bg-primary-light/70"
        >
          <span className="relative grid h-11 w-11 shrink-0 place-items-center rounded-full bg-primary text-primary-foreground">
            <MessageCircle size={20} />
            <span className="absolute -right-1 -top-1 grid h-5 min-w-5 place-items-center rounded-full bg-destructive px-1 text-[11px] font-semibold text-destructive-foreground">
              {unreadTotal}
            </span>
          </span>
          <span className="min-w-0 flex-1">
            <span className="block font-medium text-foreground">
              {unreadTotal === 1 ? '1 mensagem por ler' : `${unreadTotal} mensagens por ler`}
            </span>
            <span className="block text-sm text-muted-foreground">
              Da sua veterinária. Toque para ler.
            </span>
          </span>
          <ChevronRight size={18} className="shrink-0 text-muted-foreground" />
        </button>
      )}

      {/* Pets */}
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

      {/* Active medications */}
      {activeMeds.length > 0 && (
        <section>
          <SectionHeader className="mb-4" eyebrow="Plano" title="Medicação ativa" />
          <div className="space-y-3">
            {activeMeds.slice(0, 3).map((m) => (
              <MedicationCard
                key={m.id}
                med={m}
                petName={petNames.get(m.petId)}
                onLogDose={() => void onLog(m)}
                onUndo={() => void undoLastDose(uid, m.petId, m.id)}
                onEdit={() => navigate(`/pets/${m.petId}`)}
                onDelete={() => navigate(`/pets/${m.petId}`)}
                onSetStatus={(s: MedicationStatus) => void setMedicationStatus(uid, m.petId, m.id, s)}
              />
            ))}
            {activeMeds.length > 3 && (
              <p className="text-center text-sm text-muted-foreground">
                +{activeMeds.length - 3} {activeMeds.length - 3 === 1 ? 'outra medicação' : 'outras medicações'}
              </p>
            )}
          </div>
        </section>
      )}

      {/* Today */}
      <section>
        <SectionHeader className="mb-4" eyebrow="Agenda" title="Hoje" />
        {todayEvents.length === 0 ? (
          <Card className="flex items-center gap-3 p-4">
            <CalendarDays size={20} className="text-muted-foreground" />
            <p className="text-sm text-muted-foreground">Nada marcado para hoje</p>
          </Card>
        ) : (
          <div className="space-y-2">
            {todayEvents.map((e) => (
              <Card key={e.id} className="flex items-center gap-3 p-3">
                <span className="shrink-0 text-xs font-medium tabular-nums text-muted-foreground">
                  {timeFmt.format(e.dateTime)}
                </span>
                <span className="min-w-0 flex-1 truncate">
                  <span className="font-medium text-foreground">{e.title}</span>
                  {e.petId && petNames.get(e.petId) && (
                    <span className="text-xs text-muted-foreground"> · {petNames.get(e.petId)}</span>
                  )}
                </span>
                <Button
                  variant="ghost"
                  className="h-8 shrink-0 px-3 text-xs"
                  onClick={() => navigate('/calendar')}
                >
                  Ver
                </Button>
              </Card>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
