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
  type UserProfile,
} from '@vetplus/shared';
import { useAuth } from '@/auth/AuthProvider';
import { useCollection } from '@/lib/useFirestore';
import { clientsQuery } from '@/lib/clientService';
import { mapPatient, isPatient } from '@/lib/clinicService';
import { clinicRequestsQuery, vetRequestsQuery, mapAppointmentRequest } from '@/lib/appointmentRequestService';
import { staffRoomsQuery, clinicRoomsQuery, mapRoom } from '@/lib/chatService';
import { chatRoomPath } from '@/features/chat/useSelectedChatRoom';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { Card, CardBody } from '@/components/ui/Card';

const TIME_SHORT: Record<TimePreference, string> = {
  [TimePreference.anyTime]: 'Qualquer hora',
  [TimePreference.morning]: 'Manhã',
  [TimePreference.afternoon]: 'Tarde',
  [TimePreference.evening]: 'Noite',
};

const dayFmt = new Intl.DateTimeFormat('pt-PT', {
  weekday: 'long',
  month: 'long',
  day: 'numeric',
});

const timeFmt = new Intl.DateTimeFormat('pt-PT', { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' });

function isSameDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

function withinToday(r: AppointmentRequest): boolean {
  const now = new Date();
  const start = new Date(r.preferredDateStart);
  start.setHours(0, 0, 0, 0);
  const end = new Date(r.preferredDateEnd);
  end.setHours(23, 59, 59, 999);
  return now >= start && now <= end;
}

export function StaffDashboard({ showRequests = false }: { showRequests?: boolean }) {
  const { firebaseUser, profile, connectedClinic, role } = useAuth();
  const navigate = useNavigate();
  const uid = firebaseUser?.uid ?? '';
  const clinicId = connectedClinic?.id ?? '';
  const firstName = (profile?.displayName?.trim() || '').split(' ')[0];
  const hour = new Date().getHours();
  const greeting = hour < 12 ? 'Bom dia' : hour < 18 ? 'Boa tarde' : 'Boa noite';

  const reqQ = useMemo(() => {
    if (role === 'vet' && uid) return vetRequestsQuery(uid);
    return clinicId ? clinicRequestsQuery(clinicId) : null;
  }, [role, uid, clinicId]);
  const { data: requests } = useCollection<AppointmentRequest>(reqQ, mapAppointmentRequest);

  const pendingCount = useMemo(
    () => requests.filter((r) => r.status === AppointmentRequestStatus.pending).length,
    [requests],
  );
  const todays = useMemo(
    () =>
      requests
        .filter((r) => {
          if (r.status !== AppointmentRequestStatus.confirmed) return false;
          if (r.bookedDateTime) return isSameDay(r.bookedDateTime, new Date());
          return withinToday(r);
        })
        .sort(
          (a, b) =>
            (a.bookedDateTime ?? a.preferredDateStart).getTime() -
            (b.bookedDateTime ?? b.preferredDateStart).getTime(),
        ),
    [requests],
  );

  const clientsQ = useMemo(() => (role === 'vet' && uid ? clientsQuery(uid) : null), [role, uid]);
  const { data: clientDocs } = useCollection<UserProfile>(clientsQ, mapPatient);
  const clientCount = useMemo(() => clientDocs.filter(isPatient).length, [clientDocs]);

  const myRoomsQ = useMemo(() => (uid ? staffRoomsQuery(uid) : null), [uid]);
  const { data: myRooms } = useCollection<ChatRoom>(myRoomsQ, mapRoom);
  const unreadRooms = useMemo(
    () =>
      myRooms
        .filter((r) => r.isActive && (r.unreadCounts[uid] ?? 0) > 0)
        .sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime()),
    [myRooms, uid],
  );
  const unread = useMemo(
    () => unreadRooms.reduce((s, r) => s + (r.unreadCounts[uid] ?? 0), 0),
    [unreadRooms, uid],
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
          A sua prática
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        {showRequests && (
          <StatCard
            icon={<CalendarClock size={20} />}
            title="Pedidos de marcação"
            value={pendingCount}
            caption={pendingCount === 1 ? '1 pendente' : `${pendingCount} pendentes`}
            onClick={() => navigate('/requests')}
          />
        )}
        <StatCard
          icon={<MessageCircle size={20} />}
          title="Mensagens"
          value={unread}
          caption={
            pendingChats > 0
              ? pendingChats === 1
                ? '1 pedido pendente'
                : `${pendingChats} pedidos pendentes`
              : unread === 1
                ? '1 por ler'
                : `${unread} por ler`
          }
          onClick={() => navigate(unreadRooms[0] ? chatRoomPath(unreadRooms[0].id) : '/chat')}
        />
        <StatCard
          icon={<Users size={20} />}
          title="Clientes"
          value={0}
          caption={clientCount === 1 ? '1 cliente' : `${clientCount} clientes`}
          onClick={() => navigate('/patients')}
        />
      </div>

      <section>
        <SectionHeader className="mb-4" eyebrow="Agenda" title="Consultas de hoje" />
        {todays.length === 0 ? (
          <Card>
            <CardBody className="flex items-center gap-3 text-sm text-muted-foreground">
              <CheckCircle2 size={18} className="text-primary" />
              Sem consultas confirmadas para hoje.
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
                      <Clock size={13} />{' '}
                      {r.bookedDateTime ? timeFmt.format(r.bookedDateTime) : TIME_SHORT[r.timePreference]}
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
