import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Building2,
  Users,
  Plus,
  BarChart3,
  ListChecks,
  type LucideIcon,
} from 'lucide-react';
import { type Clinic, type UserProfile } from '@vetplus/shared';
import { useAuth } from '@/auth/AuthProvider';
import { useCollection } from '@/lib/useFirestore';
import { allClinicsQuery, mapClinic, allUsersQuery, mapPatient } from '@/lib/clinicService';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { Card, CardBody } from '@/components/ui/Card';
import { CreateClinicDialog } from './CreateClinicDialog';

const dateFmt = new Intl.DateTimeFormat(undefined, { month: 'short', day: 'numeric', year: 'numeric' });

export function AppOwnerDashboard() {
  const { profile } = useAuth();
  const navigate = useNavigate();
  const firstName = (profile?.displayName?.trim() || profile?.email || 'there').split(' ')[0];
  const hour = new Date().getHours();
  const greeting = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';

  const { data: clinics } = useCollection<Clinic>(allClinicsQuery(), mapClinic);
  const { data: users } = useCollection<UserProfile>(allUsersQuery(), mapPatient);

  const activeClinics = useMemo(() => clinics.filter((c) => c.isActive).length, [clinics]);
  const realUsers = useMemo(() => users.filter((u) => !u.id.startsWith('temp_')).length, [users]);
  const recent = useMemo(
    () => [...clinics].sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime()).slice(0, 4),
    [clinics],
  );

  const [createOpen, setCreateOpen] = useState(false);

  return (
    <div className="space-y-8">
      <SectionHeader
        as="h1"
        eyebrow="VetPlus administration"
        title={firstName ? `${greeting}, ${firstName}` : greeting}
      />

      <div className="grid gap-4 sm:grid-cols-2">
        <StatCard icon={Building2} label="Active clinics" value={activeClinics} />
        <StatCard icon={Users} label="Registered users" value={realUsers} />
      </div>

      <div className="grid gap-4 sm:grid-cols-3">
        <ActionCard
          icon={Plus}
          title="Create clinic"
          caption="Onboard a new clinic + admin"
          onClick={() => setCreateOpen(true)}
        />
        <ActionCard
          icon={ListChecks}
          title="Manage clinics"
          caption="View and edit all clinics"
          onClick={() => navigate('/clinics')}
        />
        <ActionCard
          icon={BarChart3}
          title="Analytics"
          caption="Platform statistics"
          onClick={() => navigate('/stats')}
        />
      </div>

      <section>
        <SectionHeader className="mb-4" eyebrow="Overview" title="Recent clinics" />
        {recent.length === 0 ? (
          <Card>
            <CardBody className="text-sm text-muted-foreground">No clinics yet.</CardBody>
          </Card>
        ) : (
          <div className="space-y-3">
            {recent.map((c) => (
              <Card key={c.id}>
                <CardBody className="flex items-center gap-3">
                  <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-primary-light text-primary">
                    <Building2 size={18} />
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-medium text-foreground">{c.name}</p>
                    <p className="truncate text-xs text-muted-foreground">
                      {c.address || 'No address'} · created {dateFmt.format(c.createdAt)}
                    </p>
                  </div>
                  {!c.isActive && (
                    <span className="rounded-full bg-muted px-2 py-0.5 text-[11px] font-medium text-muted-foreground">
                      Inactive
                    </span>
                  )}
                </CardBody>
              </Card>
            ))}
          </div>
        )}
      </section>

      <CreateClinicDialog open={createOpen} onClose={() => setCreateOpen(false)} />
    </div>
  );
}

function StatCard({ icon: Icon, label, value }: { icon: LucideIcon; label: string; value: number }) {
  return (
    <Card>
      <CardBody className="flex items-center gap-4">
        <span className="grid h-12 w-12 shrink-0 place-items-center rounded-full bg-primary-light text-primary">
          <Icon size={22} />
        </span>
        <div>
          <p className="font-display text-3xl font-bold tabular-nums text-foreground">{value}</p>
          <p className="text-sm text-muted-foreground">{label}</p>
        </div>
      </CardBody>
    </Card>
  );
}

function ActionCard({
  icon: Icon,
  title,
  caption,
  onClick,
}: {
  icon: LucideIcon;
  title: string;
  caption: string;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex items-center gap-3 rounded-(--radius-lg) border border-border/50 bg-card p-4 text-left shadow-(--shadow-sm) transition-[transform,background-color,box-shadow] hover:-translate-y-0.5 hover:bg-secondary hover:shadow-(--shadow-md)"
    >
      <span className="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-primary text-primary-foreground">
        <Icon size={19} />
      </span>
      <div className="min-w-0">
        <p className="font-medium text-foreground">{title}</p>
        <p className="text-xs text-muted-foreground">{caption}</p>
      </div>
    </button>
  );
}
