import { useMemo } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { toast } from 'sonner';
import { CalendarDays, Check, ChevronRight, MessageCircle, PawPrint } from 'lucide-react';
import { EventType, isActive, nextDose, type MedicationStatus } from '@vetplus/shared';
import { useFoundReports, resolveFoundReport, type FoundReport } from '@/lib/petTagService';
import { useAuth } from '@/auth/AuthProvider';
import { useCollection } from '@/lib/useFirestore';
import { petsQuery, mapPet, type Pet } from '@/lib/petService';
import { eventsQuery, mapEvent, isCancelled, type CalendarEvent } from '@/lib/eventService';
import { useRooms } from '@/lib/chatService';
import { logDoseTaken, undoLastDose, setMedicationStatus } from '@/lib/medicationService';
import { useAllMedications } from '@/lib/useAllMedications';
import { dateTimeFmt, dayHeadFmt, errorMessage, eventTitle, greeting, sameDay, timeFmt } from '@/lib/format';
import { chatRoomPath } from '@/features/chat/useSelectedChatRoom';
import { Card } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { MedicationCard } from '@/features/medications/MedicationCard';
import { t } from '@/i18n';

export function ClientDashboard() {
  const { firebaseUser, profile } = useAuth();
  const navigate = useNavigate();
  const uid = firebaseUser?.uid ?? '';

  const pq = useMemo(() => (uid ? petsQuery(uid) : null), [uid]);
  const { data: pets } = useCollection<Pet>(pq, mapPet);
  const petName = useMemo(() => new Map(pets.map((p) => [p.id, p.name])), [pets]);

  const eq = useMemo(() => (uid ? eventsQuery(uid) : null), [uid]);
  const { data: events } = useCollection<CalendarEvent>(eq, mapEvent);
  const todayEvents = events.filter(
    (e) => e.type !== EventType.medication && sameDay(e.dateTime, new Date()) && !isCancelled(e),
  );
  const upcoming = events
    .filter((e) => e.type === EventType.appointment && !isCancelled(e) && e.dateTime.getTime() >= Date.now())
    .slice(0, 3);

  const { rooms, unread } = useRooms('petOwnerId', uid);
  const { reports } = useFoundReports(uid);
  const unresolved = reports.filter((r) => !r.resolved);
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

      {unresolved.map((r) => (
        <FoundAlert key={r.id} report={r} onResolve={() => void run(resolveFoundReport(r.petId, r.id))} />
      ))}

      {unread > 0 && (
        <Banner
          icon={<MessageCircle size={20} />}
          title={t(unread === 1 ? 'dashboard.unread.one' : 'dashboard.unread.other', { count: unread })}
          subtitle={t('dashboard.fromVet')}
          onClick={() => navigate(rooms[0] ? chatRoomPath(rooms[0].id) : '/chat')}
        />
      )}

      {upcoming.length > 0 && (
        <section>
          <SectionHeader
            className="mb-4"
            eyebrow={t('common.agenda')}
            title={t('dashboard.upcoming')}
            action={
              <Button variant="ghost" onClick={() => navigate('/agenda')}>
                {t('dashboard.viewAgenda')}
              </Button>
            }
          />
          <div className="space-y-2">
            {upcoming.map((e) => (
              <Link key={e.id} to={`/agenda/consultas/${e.id}`} className="block">
                <Card className="flex items-center gap-3 p-3 transition-colors hover:bg-secondary">
                  <span className="h-2.5 w-2.5 shrink-0 rounded-full bg-event-appointment" />
                  <span className="min-w-0 flex-1">
                    <span className="block truncate font-medium text-foreground">{eventTitle(e.title)}</span>
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
          <SectionHeader className="mb-4" eyebrow={t('dashboard.plan')} title={t('dashboard.activeMeds')} />
          <div className="space-y-3">
            {activeMeds.slice(0, 3).map((m) => (
              <MedicationCard
                key={m.id}
                med={m}
                petName={petName.get(m.petId)}
                onLogDose={() => void run(logDoseTaken(uid, m.petId, m.id, new Date()), t('agenda.doseLogged'))}
                onUndo={() => void run(undoLastDose(uid, m.petId, m.id))}
                onEdit={() => navigate(`/pets/${m.petId}`)}
                onDelete={() => navigate(`/pets/${m.petId}`)}
                onSetStatus={(s: MedicationStatus) => void run(setMedicationStatus(uid, m.petId, m.id, s))}
              />
            ))}
            {activeMeds.length > 3 && (
              <p className="text-center text-sm text-muted-foreground">
                {t(activeMeds.length - 3 === 1 ? 'dashboard.moreMeds.one' : 'dashboard.moreMeds.other', {
                  count: activeMeds.length - 3,
                })}
              </p>
            )}
          </div>
        </section>
      )}

      <section>
        <SectionHeader className="mb-4" eyebrow={t('common.agenda')} title={t('common.today')} />
        {todayEvents.length === 0 ? (
          <Card className="flex items-center gap-3 p-4">
            <CalendarDays size={20} className="text-muted-foreground" />
            <p className="text-sm text-muted-foreground">{t('dashboard.nothingToday')}</p>
          </Card>
        ) : (
          <div className="space-y-2">
            {todayEvents.map((e) => (
              <Link
                key={e.id}
                to={e.type === EventType.appointment ? `/agenda/consultas/${e.id}` : '/agenda'}
                className="block"
              >
                <Card className="flex items-center gap-3 p-3 transition-colors hover:bg-secondary">
                  <span className="shrink-0 text-xs font-medium tabular-nums text-muted-foreground">
                    {timeFmt.format(e.dateTime)}
                  </span>
                  <span className="min-w-0 flex-1 truncate">
                    <span className="font-medium text-foreground">{eventTitle(e.title)}</span>
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

/** Finder-contact link: tel: for phone-shaped contacts, mailto: for emails. */
function contactLink(contact: string) {
  const digits = contact.replace(/\D/g, '');
  if (digits.length >= 6 && /^[+\d][\d\s\-()]*$/.test(contact)) return `tel:${contact}`;
  if (contact.includes('@')) return `mailto:${contact}`;
  return null;
}

/** Highlighted "pet was found" alert on the client dashboard. */
function FoundAlert({ report: r, onResolve }: { report: FoundReport; onResolve: () => void }) {
  const href = contactLink(r.finderContact);
  return (
    <Card className="border-warning/40 bg-warning/15 p-4">
      <div className="flex items-start gap-3">
        <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-warning/20 text-warning">
          <PawPrint size={18} />
        </span>
        <div className="min-w-0 flex-1">
          <p className="font-medium text-foreground">{t('tag.foundToast', { name: r.petName })}</p>
          <p className="mt-0.5 text-sm text-muted-foreground">
            {r.finderName || t('tag.someone')}
            {r.message ? ` — ${r.message}` : ''}
          </p>
          <p className="mt-1 text-sm">
            {href ? (
              <a href={href} className="font-medium text-foreground underline">
                {r.finderContact}
              </a>
            ) : (
              <span className="text-foreground">{r.finderContact}</span>
            )}
            {r.createdAt && (
              <span className="text-muted-foreground"> · {dateTimeFmt.format(r.createdAt)}</span>
            )}
          </p>
        </div>
        <Button variant="outline" size="md" className="shrink-0" onClick={onResolve}>
          <Check size={15} /> {t('tag.resolve')}
        </Button>
      </div>
    </Card>
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
