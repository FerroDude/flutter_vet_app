import { useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  CalendarClock,
  MessageCircle,
  ChevronRight,
  PawPrint,
  Clock,
  CheckCircle2,
  Users,
} from 'lucide-react';
import {
  type AppointmentRequest,
  AppointmentRequestStatus,
  TimePreference,
  type ChatRoom,
  ChatRoomStatus,
} from '@vetplus/shared';
import { useAuth } from '@/auth/AuthProvider';
import { useCollection } from '@/lib/useFirestore';
import { clinicRequestsQuery, mapAppointmentRequest } from '@/lib/appointmentRequestService';
import { staffRoomsQuery, clinicRoomsQuery, mapRoom } from '@/lib/chatService';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { Card, CardBody } from '@/components/ui/Card';

const TIME_SHORT: Record<TimePreference, string> = {
  [TimePreference.anyTime]: 'Any time',
  [TimePreference.morning]: 'Morning',
  [TimePreference.afternoon]: 'Afternoon',
  [TimePreference.evening]: 'Evening',
};

const dayFmt = new Intl.DateTimeFormat(undefined, {
  weekday: 'long',
  month: 'long',
  day: 'numeric',
});

function withinToday(r: AppointmentRequest): boolean {
  const now = new Date();
  const start = new Date(r.preferredDateStart);
  start.setHours(0, 0, 0, 0);
  const end = new Date(r.preferredDateEnd);
  end.setHours(23, 59, 59, 999);
  return now >= start && now <= end;
}

export function StaffDashboard({ showRequests = false }: { showRequests?: boolean }) {
  const { firebaseUser, profile, connectedClinic } = useAuth();
  const navigate = useNavigate();
  const uid = firebaseUser?.uid ?? '';
  const clinicId = connectedClinic?.id ?? '';
  const firstName = (profile?.displayName?.trim() || profile?.email || 'there').split(' ')[0];
  const hour = new Date().getHours();
  const greeting = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';

  const reqQ = useMemo(() => (clinicId ? clinicRequestsQuery(clinicId) : null), [clinicId]);
  const { data: requests } = useCollection<AppointmentRequest>(reqQ, mapAppointmentRequest);

  const pendingCount = useMemo(
    () => requests.filter((r) => r.status === AppointmentRequestStatus.pending).length,
    [requests],
  );
  const todays = useMemo(
    () =>
      requests
        .filter((r) => r.status === AppointmentRequestStatus.confirmed && withinToday(r))
        .sort((a, b) => a.preferredDateStart.getTime() - b.preferredDateStart.getTime()),
    [requests],
  );

  const myRoomsQ = useMemo(() => (uid ? staffRoomsQuery(uid) : null), [uid]);
  const { data: myRooms } = useCollection<ChatRoom>(myRoomsQ, mapRoom);
  const unread = useMemo(
    () => myRooms.filter((r) => r.isActive).reduce((s, r) => s + (r.unreadCounts[uid] ?? 0), 0),
    [myRooms, uid],
  );

  const clinicRoomsQ = useMemo(() => (clinicId ? clinicRoomsQuery(clinicId) : null), [clinicId]);
  const { data: clinicRooms } = useCollection<ChatRoom>(clinicRoomsQ, mapRoom);
  const pendingChats = useMemo(
    () => clinicRooms.filter((r) => r.isActive && r.status === ChatRoomStatus.pending).length,
    [clinicRooms],
  );

  return (
    <div className="space-y-8">
      <div>
        <SectionHeader
          as="h1"
          eyebrow={dayFmt.format(new Date())}
          title={firstName ? `${greeting}, ${firstName}` : greeting}
        />
        <p className="mt-1.5 text-sm text-muted-foreground">
          {connectedClinic?.name ?? 'Your clinic'}
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        {showRequests && (
          <StatCard
            icon={<CalendarClock size={20} />}
            title="Appointment requests"
            value={pendingCount}
            caption={pendingCount === 1 ? '1 pending' : `${pendingCount} pending`}
            onClick={() => navigate('/requests')}
          />
        )}
        <StatCard
          icon={<MessageCircle size={20} />}
          title="Messages"
          value={unread}
          caption={
            pendingChats > 0
              ? `${pendingChats} pending request${pendingChats === 1 ? '' : 's'}`
              : unread === 1
                ? '1 unread'
                : `${unread} unread`
          }
          onClick={() => navigate('/chat')}
        />
        <StatCard
          icon={<Users size={20} />}
          title="Patients"
          value={0}
          caption="View pet owners"
          onClick={() => navigate('/patients')}
        />
      </div>

      <section>
        <SectionHeader className="mb-4" eyebrow="Schedule" title="Today's appointments" />
        {todays.length === 0 ? (
          <Card>
            <CardBody className="flex items-center gap-3 text-sm text-muted-foreground">
              <CheckCircle2 size={18} className="text-primary" />
              No confirmed appointments scheduled for today.
            </CardBody>
          </Card>
        ) : (
          <div className="space-y-3">
            {todays.map((r) => (
              <Card key={r.id}>
                <CardBody className="flex items-center gap-3">
                  <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-primary-light text-primary">
                    <PawPrint size={18} />
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-medium text-foreground">
                      {r.petName}
                      <span className="font-normal text-muted-foreground"> · {r.petOwnerName}</span>
                    </p>
                    <p className="flex items-center gap-1.5 text-sm text-muted-foreground">
                      <Clock size={13} /> {TIME_SHORT[r.timePreference]}
                    </p>
                  </div>
                </CardBody>
              </Card>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}

function StatCard({
  icon,
  title,
  value,
  caption,
  onClick,
}: {
  icon: React.ReactNode;
  title: string;
  value: number;
  caption: string;
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
        {value > 0 && (
          <span className="absolute -right-1 -top-1 grid h-5 min-w-5 place-items-center rounded-full bg-destructive px-1 text-[11px] font-semibold text-destructive-foreground">
            {value}
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
