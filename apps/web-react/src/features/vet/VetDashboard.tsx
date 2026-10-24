import { useNavigate } from 'react-router-dom';
import { CalendarClock, CheckCircle2, ChevronRight, Clock, MessageCircle, PawPrint, Users } from 'lucide-react';
import { useAuth } from '@/auth/AuthProvider';
import { useClients } from '@/lib/useClients';
import { useRooms } from '@/lib/chatService';
import { useVetAppointments } from '@/lib/useVetAppointments';
import { useVetPendingRequests } from '@/lib/appointmentRequestService';
import { dateTimeFmt, dayHeadFmt, dayShortFmt, eventTitle, greeting, sameDay, timeFmt } from '@/lib/format';
import { chatRoomPath } from '@/features/chat/useSelectedChatRoom';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { t } from '@/i18n';
import { Card, CardBody } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';

export function VetDashboard() {
  const { firebaseUser, profile } = useAuth();
  const navigate = useNavigate();
  const uid = firebaseUser?.uid ?? '';
  const firstName = (profile?.displayName?.trim() || '').split(' ')[0];

  const pending = useVetPendingRequests(uid);
  const { clients } = useClients(uid);
  const { rooms, unread } = useRooms('vetId', uid);
  const { appointments } = useVetAppointments(uid);
  const upcoming = appointments
    .filter((a) => !a.cancelledAt && a.dateTime.getTime() >= Date.now())
    .slice(0, 5);
  const recentCancels = appointments
    .filter((a) => a.cancelledAt && Date.now() - a.cancelledAt.getTime() < 7 * 86_400_000)
    .sort((a, b) => b.cancelledAt!.getTime() - a.cancelledAt!.getTime())
    .slice(0, 5);

  const now = new Date();
  const tomorrow = new Date(now);
  tomorrow.setDate(tomorrow.getDate() + 1);
  const dayLabel = (d: Date) =>
    sameDay(d, now) ? t('common.today') : sameDay(d, tomorrow) ? t('common.tomorrow') : dayShortFmt.format(d);
  const firstUnread = rooms.find((r) => (r.unreadCounts[uid] ?? 0) > 0);

  return (
    <div className="space-y-8">
      <SectionHeader
        as="h1"
        eyebrow={dayHeadFmt.format(new Date())}
        title={firstName ? `${greeting()}, ${firstName}` : greeting()}
      />

      <div className="grid gap-4 sm:grid-cols-3">
        <StatCard
          icon={<CalendarClock size={20} />}
          title={t('vetDash.requests')}
          alert={pending.length}
          caption={t(pending.length === 1 ? 'vetDash.pending.one' : 'vetDash.pending.other', { count: pending.length })}
          onClick={() => navigate('/agenda')}
        />
        <StatCard
          icon={<MessageCircle size={20} />}
          title={t('vetDash.messages')}
          alert={unread}
          caption={t(unread === 1 ? 'vetDash.unread.one' : 'vetDash.unread.other', { count: unread })}
          onClick={() => navigate(firstUnread ? chatRoomPath(firstUnread.id) : '/chat')}
        />
        <StatCard
          icon={<Users size={20} />}
          title={t('vetDash.clients')}
          caption={t(clients.length === 1 ? 'vetDash.clients.one' : 'vetDash.clients.other', { count: clients.length })}
          onClick={() => navigate('/clients')}
        />
      </div>

      <section>
        <SectionHeader
          className="mb-4"
          eyebrow={t('nav.agenda')}
          title={t('vetDash.upcoming')}
          action={
            <Button variant="ghost" onClick={() => navigate('/agenda')}>
              {t('vet.viewAgenda')}
            </Button>
          }
        />
        {upcoming.length === 0 ? (
          <Card>
            <CardBody className="flex items-center gap-3 text-sm text-muted-foreground">
              <CheckCircle2 size={18} className="text-primary" />
              {t('vetDash.noAppointments')}
            </CardBody>
          </Card>
        ) : (
          <div className="space-y-3">
            {upcoming.map((a) => (
              <button
                key={`${a.userId}/${a.id}`}
                type="button"
                onClick={() => navigate('/agenda')}
                className="block w-full text-left"
              >
                <Card className="transition-colors hover:bg-secondary">
                  <CardBody className="flex items-center gap-3">
                    <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-primary-light text-primary">
                      <PawPrint size={18} />
                    </span>
                    <div className="min-w-0 flex-1">
                      <p className="truncate font-medium text-foreground">
                        {a.petName || eventTitle(a.title)}
                        <span className="font-normal text-muted-foreground"> · {a.clientName || t('common.client')}</span>
                      </p>
                      <p className="flex items-center gap-1.5 text-sm text-muted-foreground">
                        <Clock size={13} /> {dayLabel(a.dateTime)}, {timeFmt.format(a.dateTime)}
                        {a.location ? ` · ${a.location}` : ''}
                      </p>
                    </div>
                  </CardBody>
                </Card>
              </button>
            ))}
          </div>
        )}
      </section>
      {recentCancels.length > 0 && (
        <section>
          <SectionHeader className="mb-4" eyebrow={t('nav.agenda')} title={t('vetDash.recentCancels')} />
          <div className="space-y-3">
            {recentCancels.map((a) => (
              <button
                key={`${a.userId}/${a.id}`}
                type="button"
                onClick={() => navigate('/agenda')}
                className="block w-full text-left"
              >
                <Card className="transition-colors hover:bg-secondary">
                  <CardBody className="flex items-center gap-3">
                    <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-primary-light text-primary">
                      <PawPrint size={18} />
                    </span>
                    <div className="min-w-0 flex-1">
                      <p className="truncate font-medium text-foreground">
                        {a.petName || eventTitle(a.title)}
                        <span className="font-normal text-muted-foreground"> · {a.clientName || t('common.client')}</span>
                      </p>
                      <p className="text-sm text-muted-foreground">{dateTimeFmt.format(a.dateTime)}</p>
                      {a.cancelReason && (
                        <p className="mt-0.5 truncate text-sm italic text-muted-foreground">
                          “{a.cancelReason}”
                        </p>
                      )}
                    </div>
                  </CardBody>
                </Card>
              </button>
            ))}
          </div>
        </section>
      )}
    </div>
  );
}

function StatCard({
  icon,
  title,
  caption,
  alert = 0,
  onClick,
}: {
  icon: React.ReactNode;
  title: string;
  caption: string;
  /** Red badge count for things that need attention. */
  alert?: number;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex items-center gap-4 rounded-(--radius-lg) border border-border/50 bg-card p-5 text-left shadow-(--shadow-sm) transition-[transform,background-color,box-shadow] hover:-translate-y-0.5 hover:bg-secondary hover:shadow-(--shadow-md)"
    >
      <span className="relative grid h-12 w-12 shrink-0 place-items-center rounded-full bg-primary text-primary-foreground">
        {icon}
        {alert > 0 && (
          <span className="absolute -right-1 -top-1 grid h-5 min-w-5 place-items-center rounded-full bg-destructive px-1 text-[11px] font-semibold text-destructive-foreground">
            {alert}
          </span>
        )}
      </span>
      <div className="min-w-0 flex-1">
        <p className="font-medium text-foreground">{title}</p>
        <p className="text-sm text-muted-foreground">{caption}</p>
      </div>
      <ChevronRight size={18} className="shrink-0 text-muted-foreground" />
    </button>
  );
}
