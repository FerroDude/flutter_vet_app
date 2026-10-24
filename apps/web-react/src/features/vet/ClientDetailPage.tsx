import { useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { toast } from 'sonner';
import { doc } from 'firebase/firestore';
import {
  ArrowLeft,
  Mail,
  Phone,
  MapPin,
  ChevronRight,
  MessageSquare,
  Plus,
  CalendarDays,
  CalendarPlus,
} from 'lucide-react';
import { useVetAppointments } from '@/lib/useVetAppointments';
import { VetAppointmentDialog } from './VetAppointmentDialog';
import { type UserProfile } from '@vetplus/shared';
import { useAuth } from '@/auth/AuthProvider';
import { db } from '@/lib/firebase';
import { useDoc, useCollection } from '@/lib/useFirestore';
import { clientLabel, mapClient } from '@/lib/clientService';
import { dateTimeFmt, errorMessage, eventTitle, fullAddress } from '@/lib/format';
import { petsQuery, mapPet, petAgeLabel, type Pet } from '@/lib/petService';
import { findOrCreateOneOnOneChat } from '@/lib/chatService';
import { chatRoomPath } from '@/features/chat/useSelectedChatRoom';
import { PageHeader } from '@/components/ui/PageHeader';
import { t } from '@/i18n';
import { PetAvatar } from '@/components/ui/PetAvatar';
import { Card, CardBody } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Spinner } from '@/components/Spinner';

export function ClientDetailPage() {
  const { ownerId = '' } = useParams();
  const { firebaseUser, profile } = useAuth();
  const navigate = useNavigate();
  const uid = firebaseUser?.uid ?? '';
  const staffName = profile?.displayName?.trim() || profile?.email || t('common.vet');

  const ownerRef = useMemo(() => doc(db, 'users', ownerId), [ownerId]);
  const { data: owner, loading } = useDoc<UserProfile>(ownerRef, mapClient);

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
        petOwnerName: clientLabel(owner),
        vetId: uid,
        vetName: staffName,
      });
      navigate(chatRoomPath(roomId));
    } catch (e) {
      toast.error(errorMessage(e, t('vet.chatOpenFailed')));
    } finally {
      setStarting(false);
    }
  };

  return (
    <div className="mx-auto max-w-3xl">
      <button
        type="button"
        onClick={() => navigate('/clients')}
        className="mb-4 inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft size={16} /> {t('vet.clients')}
      </button>

      {loading && !owner ? (
        <div className="flex justify-center py-16">
          <Spinner size={28} />
        </div>
      ) : !owner ? (
        <PageHeader title={t('vet.clientNotFound')} subtitle={t('vet.clientGone')} />
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
                    {owner.displayName || t('vet.noName')}
                  </p>
                </div>
              </div>
              <div className="flex flex-wrap gap-2">
                <Button loading={starting} onClick={() => void startChat()}>
                  <MessageSquare size={16} /> {t('vet.message')}
                </Button>
                <Button variant="outline" onClick={() => setBookOpen(true)}>
                  <CalendarPlus size={16} /> {t('vet.book')}
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
                {fullAddress(owner) && (
                  <span className="flex min-w-0 items-start gap-2 text-muted-foreground">
                    <MapPin size={15} className="mt-0.5 shrink-0" />
                    <span className="break-words">{fullAddress(owner)}</span>
                  </span>
                )}
              </div>
            </CardBody>
          </Card>

          {clientUpcoming.length > 0 && (
            <div className="mb-6">
              <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                {t('vet.upcoming')}
              </h2>
              <Card>
                <ul className="divide-y divide-border">
                  {clientUpcoming.map((a) => (
                    <li key={a.id} className="flex items-center gap-3 px-4 py-3 text-sm">
                      <CalendarDays size={15} className="shrink-0 text-primary" />
                      <span className="shrink-0 font-medium tabular-nums text-foreground">
                        {dateTimeFmt.format(a.dateTime)}
                      </span>
                      <span className="min-w-0 truncate text-muted-foreground">{eventTitle(a.title)}</span>
                    </li>
                  ))}
                </ul>
              </Card>
            </div>
          )}

          <div className="mb-2 flex flex-wrap items-center justify-between gap-3">
            <h2 className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
              {t('vet.petsCount', { count: pets.length })}
            </h2>
            <Button variant="outline" onClick={() => navigate(`/clients/${ownerId}/pets/new`)}>
              <Plus size={15} /> {t('vet.addPet')}
            </Button>
          </div>
          {pets.length === 0 ? (
            <Card>
              <CardBody className="text-sm text-muted-foreground">
                {t('vet.noPets')}
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

function PetCard({ ownerId, pet }: { ownerId: string; pet: Pet }) {
  const navigate = useNavigate();
  return (
    <Card>
      <button
        type="button"
        onClick={() => navigate(`/clients/${ownerId}/pets/${pet.id}`)}
        className="flex w-full items-center gap-3 p-4 text-left transition-colors hover:bg-secondary"
      >
        <PetAvatar pet={pet} size={40} />
        <span className="min-w-0 flex-1">
          <span className="block truncate font-medium text-foreground">{pet.name}</span>
          <span className="block truncate text-xs text-muted-foreground">
            {[pet.species, pet.breed].filter(Boolean).join(' · ') || t('pets.unknown')} · {petAgeLabel(pet.dateOfBirth)}
          </span>
        </span>
        <ChevronRight size={18} className="shrink-0 text-muted-foreground" />
      </button>
    </Card>
  );
}
