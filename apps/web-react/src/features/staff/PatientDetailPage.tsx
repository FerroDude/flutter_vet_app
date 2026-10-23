import { useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { toast } from 'sonner';
import { doc } from 'firebase/firestore';
import {
  ArrowLeft,
  Mail,
  Phone,
  MapPin,
  PawPrint,
  ChevronDown,
  MessageSquare,
  Activity,
  Plus,
  CalendarDays,
  CalendarPlus,
} from 'lucide-react';
import { useVetAppointments } from '@/lib/useVetAppointments';
import { VetAppointmentDialog } from './VetAppointmentDialog';
import {
  type UserProfile,
  type PetSymptom,
  SYMPTOM_LABELS,
} from '@vetplus/shared';
import { useAuth, type Role } from '@/auth/AuthProvider';
import { db } from '@/lib/firebase';
import { useDoc, useCollection } from '@/lib/useFirestore';
import { mapPatient } from '@/lib/clinicService';
import {
  petsQuery,
  mapPet,
  petAgeLabel,
  symptomsQuery,
  mapSymptom,
  type Pet,
} from '@/lib/petService';
import { findOrCreateOneOnOneChat } from '@/lib/chatService';
import { chatRoomPath } from '@/features/chat/useSelectedChatRoom';
import { PageHeader } from '@/components/ui/PageHeader';
import { Card, CardBody } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Spinner } from '@/components/Spinner';

const STAFF_ROLE: Partial<Record<Role, string>> = {
  vet: 'vet',
  receptionist: 'receptionist',
  clinicAdmin: 'admin',
};

export function PatientDetailPage() {
  const { ownerId = '' } = useParams();
  const { firebaseUser, profile, role } = useAuth();
  const navigate = useNavigate();
  const uid = firebaseUser?.uid ?? '';
  const staffName = profile?.displayName?.trim() || profile?.email || 'Veterinária';

  const ownerRef = useMemo(() => doc(db, 'users', ownerId), [ownerId]);
  const { data: owner, loading } = useDoc<UserProfile>(ownerRef, mapPatient);

  const petsQ = useMemo(() => (ownerId ? petsQuery(ownerId) : null), [ownerId]);
  const { data: pets } = useCollection<Pet>(petsQ, mapPet);

  const [starting, setStarting] = useState(false);
  const [bookOpen, setBookOpen] = useState(false);
  const { appointments } = useVetAppointments(uid);
  const clientUpcoming = useMemo(() => {
    const now = Date.now();
    return appointments.filter((a) => a.userId === ownerId && a.dateTime.getTime() >= now);
  }, [appointments, ownerId]);
  const [bookDay] = useState(() => new Date());

  const startChat = async () => {
    if (!owner) return;
    setStarting(true);
    try {
      const roomId = await findOrCreateOneOnOneChat({
        petOwnerId: ownerId,
        petOwnerName: owner.displayName || owner.email || 'Cliente',
        staffId: uid,
        staffName,
        staffRole: STAFF_ROLE[role] ?? 'vet',
        petIds: pets.map((p) => p.id),
      });
      toast.success('Conversa aberta');
      navigate(chatRoomPath(roomId));
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Não foi possível abrir a conversa');
    } finally {
      setStarting(false);
    }
  };

  return (
    <div className="mx-auto max-w-3xl">
      <button
        type="button"
        onClick={() => navigate('/patients')}
        className="mb-4 inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft size={16} /> Clientes
      </button>

      {loading && !owner ? (
        <div className="flex justify-center py-16">
          <Spinner size={28} />
        </div>
      ) : !owner ? (
        <PageHeader title="Cliente não encontrado" subtitle="Este cliente já não existe." />
      ) : (
        <>
          <Card className="mb-6">
            <CardBody className="space-y-4">
              <div className="flex items-center gap-4">
                <span className="grid h-14 w-14 shrink-0 place-items-center rounded-full bg-primary-light text-xl font-semibold text-primary">
                  {(owner.displayName || owner.email || '?').charAt(0).toUpperCase()}
                </span>
                <div className="min-w-0 flex-1">
                  <p className="truncate font-display text-2xl font-bold text-foreground">
                    {owner.displayName || 'Sem nome'}
                  </p>
                </div>
              </div>
              <div className="flex flex-wrap gap-2">
                <Button loading={starting} onClick={() => void startChat()}>
                  <MessageSquare size={16} /> Mensagem
                </Button>
                <Button variant="outline" onClick={() => setBookOpen(true)}>
                  <CalendarPlus size={16} /> Marcar consulta
                </Button>
              </div>
              <div className="grid gap-2 text-sm sm:grid-cols-2">
                {owner.email && (
                  <a
                    href={`mailto:${owner.email}`}
                    className="flex min-w-0 items-center gap-2 text-muted-foreground hover:text-foreground"
                  >
                    <Mail size={15} className="shrink-0" />
                    <span className="break-all">{owner.email}</span>
                  </a>
                )}
                {owner.phone && (
                  <a
                    href={`tel:${owner.phone}`}
                    className="flex min-w-0 items-center gap-2 text-muted-foreground hover:text-foreground"
                  >
                    <Phone size={15} className="shrink-0" /> {owner.phone}
                  </a>
                )}
                {owner.address && (
                  <span className="flex min-w-0 items-start gap-2 text-muted-foreground">
                    <MapPin size={15} className="mt-0.5 shrink-0" />
                    <span className="break-words">{owner.address}</span>
                  </span>
                )}
              </div>
            </CardBody>
          </Card>

          {clientUpcoming.length > 0 && (
            <div className="mb-6">
              <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                Próximas consultas
              </h2>
              <Card>
                <ul className="divide-y divide-border">
                  {clientUpcoming.map((a) => (
                    <li key={a.id} className="flex items-center gap-3 px-4 py-3 text-sm">
                      <CalendarDays size={15} className="shrink-0 text-primary" />
                      <span className="shrink-0 font-medium tabular-nums text-foreground">
                        {apptFmt.format(a.dateTime)}
                      </span>
                      <span className="min-w-0 truncate text-muted-foreground">{a.title}</span>
                    </li>
                  ))}
                </ul>
              </Card>
            </div>
          )}

          <div className="mb-2 flex flex-wrap items-center justify-between gap-3">
            <h2 className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
              Animais ({pets.length})
            </h2>
            <Button variant="outline" onClick={() => navigate(`/patients/${ownerId}/pets/new`)}>
              <Plus size={15} /> Adicionar animal
            </Button>
          </div>
          {pets.length === 0 ? (
            <Card>
              <CardBody className="text-sm text-muted-foreground">
                Este cliente ainda não tem animais.
              </CardBody>
            </Card>
          ) : (
            <div className="space-y-3">
              {pets.map((p) => (
                <PetCard key={p.id} ownerId={ownerId} pet={p} />
              ))}
            </div>
          )}
        </>
      )}

      <VetAppointmentDialog
        open={bookOpen}
        onClose={() => setBookOpen(false)}
        vetId={uid}
        vetName={staffName}
        defaultDay={bookDay}
        presetClientId={ownerId}
        others={appointments}
      />
    </div>
  );
}

const apptFmt = new Intl.DateTimeFormat('pt-PT', {
  weekday: 'short',
  day: 'numeric',
  month: 'short',
  hour: '2-digit',
  minute: '2-digit',
  hourCycle: 'h23',
});

function PetCard({ ownerId, pet }: { ownerId: string; pet: Pet }) {
  const [open, setOpen] = useState(false);
  const navigate = useNavigate();
  return (
    <Card>
      <CardBody className="p-0">
        <button
          type="button"
          onClick={() => setOpen((v) => !v)}
          className="flex w-full items-center gap-3 p-4 text-left"
        >
          <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-primary-light text-primary">
            <PawPrint size={18} />
          </span>
          <span className="min-w-0 flex-1">
            <span className="block truncate font-medium text-foreground">{pet.name}</span>
            <span className="block truncate text-xs text-muted-foreground">
              {[pet.species, pet.breed].filter(Boolean).join(' · ') || 'Animal'} ·{' '}
              {petAgeLabel(pet.dateOfBirth)}
            </span>
          </span>
          <ChevronDown
            size={18}
            className={'shrink-0 text-muted-foreground transition-transform ' + (open ? 'rotate-180' : '')}
          />
        </button>
        {open && (
          <div className="border-t border-border px-4 py-3">
            {pet.medicalNotes && (
              <p className="mb-3 whitespace-pre-wrap break-words text-sm text-muted-foreground">
                <span className="font-medium text-foreground">Notas: </span>
                {pet.medicalNotes}
              </p>
            )}
            <PetSymptoms ownerId={ownerId} petId={pet.id} />
            <Button
              variant="outline"
              className="mt-3"
              onClick={() => navigate(`/patients/${ownerId}/pets/${pet.id}`)}
            >
              Abrir ficha
            </Button>
          </div>
        )}
      </CardBody>
    </Card>
  );
}

const symptomDateFmt = new Intl.DateTimeFormat('pt-PT', {
  month: 'short',
  day: 'numeric',
  hour: 'numeric',
  minute: '2-digit',
});

function PetSymptoms({ ownerId, petId }: { ownerId: string; petId: string }) {
  const q = useMemo(() => symptomsQuery(ownerId, petId), [ownerId, petId]);
  const { data, loading } = useCollection<PetSymptom>(q, (id, d) =>
    mapSymptom(ownerId, petId, id, d),
  );
  const recent = useMemo(() => data.slice(0, 10), [data]);

  if (loading && data.length === 0) {
    return <p className="text-sm text-muted-foreground">A carregar sintomas…</p>;
  }
  if (recent.length === 0) {
    return <p className="text-sm text-muted-foreground">Sem sintomas registados.</p>;
  }
  return (
    <div className="space-y-2">
      <p className="flex items-center gap-1.5 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
        <Activity size={13} /> Sintomas recentes
      </p>
      {recent.map((s) => (
        <div key={s.id} className="flex items-start gap-2 text-sm">
          <span className="mt-1.5 h-1.5 w-1.5 shrink-0 rounded-full bg-primary" />
          <div className="min-w-0">
            <span className="font-medium text-foreground">{SYMPTOM_LABELS[s.type]}</span>
            <span className="text-muted-foreground"> · {symptomDateFmt.format(s.timestamp)}</span>
            {s.note && <p className="whitespace-pre-wrap break-words text-muted-foreground">{s.note}</p>}
          </div>
        </div>
      ))}
    </div>
  );
}
