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
} from 'lucide-react';
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
  const { firebaseUser, profile, role, connectedClinic } = useAuth();
  const navigate = useNavigate();
  const uid = firebaseUser?.uid ?? '';
  const staffName = profile?.displayName?.trim() || profile?.email || 'Clinic';

  const ownerRef = useMemo(() => doc(db, 'users', ownerId), [ownerId]);
  const { data: owner, loading } = useDoc<UserProfile>(ownerRef, mapPatient);

  const petsQ = useMemo(() => (ownerId ? petsQuery(ownerId) : null), [ownerId]);
  const { data: pets } = useCollection<Pet>(petsQ, mapPet);

  const [starting, setStarting] = useState(false);

  const startChat = async () => {
    if (!connectedClinic || !owner) return;
    setStarting(true);
    try {
      const roomId = await findOrCreateOneOnOneChat({
        clinicId: connectedClinic.id,
        petOwnerId: ownerId,
        petOwnerName: owner.displayName || owner.email || 'Pet owner',
        staffId: uid,
        staffName,
        staffRole: STAFF_ROLE[role] ?? 'vet',
        petIds: pets.map((p) => p.id),
      });
      void roomId;
      toast.success('Chat opened');
      navigate('/chat');
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not start chat');
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
        <ArrowLeft size={16} /> Patients
      </button>

      {loading && !owner ? (
        <div className="flex justify-center py-16">
          <Spinner size={28} />
        </div>
      ) : !owner ? (
        <PageHeader title="Patient not found" subtitle="This pet owner no longer exists." />
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
                    {owner.displayName || 'Unnamed'}
                  </p>
                </div>
                <Button loading={starting} onClick={() => void startChat()}>
                  <MessageSquare size={16} /> Message
                </Button>
              </div>
              <div className="grid gap-2 text-sm sm:grid-cols-2">
                {owner.email && (
                  <span className="inline-flex items-center gap-2 text-muted-foreground">
                    <Mail size={15} /> {owner.email}
                  </span>
                )}
                {owner.phone && (
                  <span className="inline-flex items-center gap-2 text-muted-foreground">
                    <Phone size={15} /> {owner.phone}
                  </span>
                )}
                {owner.address && (
                  <span className="inline-flex items-center gap-2 text-muted-foreground">
                    <MapPin size={15} /> {owner.address}
                  </span>
                )}
              </div>
            </CardBody>
          </Card>

          <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
            Pets ({pets.length})
          </h2>
          {pets.length === 0 ? (
            <Card>
              <CardBody className="text-sm text-muted-foreground">
                This owner hasn't added any pets yet.
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
    </div>
  );
}

function PetCard({ ownerId, pet }: { ownerId: string; pet: Pet }) {
  const [open, setOpen] = useState(false);
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
              {[pet.species, pet.breed].filter(Boolean).join(' · ') || 'Pet'} ·{' '}
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
              <p className="mb-3 text-sm text-muted-foreground">
                <span className="font-medium text-foreground">Notes: </span>
                {pet.medicalNotes}
              </p>
            )}
            <PetSymptoms ownerId={ownerId} petId={pet.id} />
          </div>
        )}
      </CardBody>
    </Card>
  );
}

const symptomDateFmt = new Intl.DateTimeFormat(undefined, {
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
    return <p className="text-sm text-muted-foreground">Loading symptoms…</p>;
  }
  if (recent.length === 0) {
    return <p className="text-sm text-muted-foreground">No symptoms logged.</p>;
  }
  return (
    <div className="space-y-2">
      <p className="flex items-center gap-1.5 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
        <Activity size={13} /> Recent symptoms
      </p>
      {recent.map((s) => (
        <div key={s.id} className="flex items-start gap-2 text-sm">
          <span className="mt-1.5 h-1.5 w-1.5 shrink-0 rounded-full bg-primary" />
          <div className="min-w-0">
            <span className="font-medium text-foreground">{SYMPTOM_LABELS[s.type]}</span>
            <span className="text-muted-foreground"> · {symptomDateFmt.format(s.timestamp)}</span>
            {s.note && <p className="text-muted-foreground">{s.note}</p>}
          </div>
        </div>
      ))}
    </div>
  );
}
