import { useNavigate } from 'react-router-dom';
import {
  Building2,
  Users,
  Stethoscope,
  Settings,
  MessageCircle,
  Mail,
  Phone,
  MapPin,
  Globe,
  type LucideIcon,
} from 'lucide-react';
import { useAuth } from '@/auth/AuthProvider';
import { PageHeader } from '@/components/ui/PageHeader';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { Card, CardBody } from '@/components/ui/Card';
import { EmptyState } from '@/components/ui/EmptyState';

export function AdminDashboard() {
  const { profile, connectedClinic } = useAuth();
  const navigate = useNavigate();
  const firstName = (profile?.displayName?.trim() || profile?.email || 'there').split(' ')[0];
  const hour = new Date().getHours();
  const greeting = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';

  if (!connectedClinic) {
    return (
      <div>
        <PageHeader title="Dashboard" />
        <EmptyState
          icon={<Building2 size={36} />}
          title="No clinic linked"
          description="Your admin account isn't linked to a clinic yet."
        />
      </div>
    );
  }

  return (
    <div className="space-y-8">
      <SectionHeader
        as="h1"
        eyebrow="Clinic admin"
        title={firstName ? `${greeting}, ${firstName}` : greeting}
      />

      {/* Clinic overview */}
      <Card>
        <CardBody className="space-y-4">
          <div className="flex items-center gap-3">
            <span className="grid h-12 w-12 shrink-0 place-items-center rounded-full bg-primary-light text-primary">
              <Building2 size={22} />
            </span>
            <div className="min-w-0">
              <p className="truncate font-display text-xl font-bold text-foreground">
                {connectedClinic.name}
              </p>
              {connectedClinic.description && (
                <p className="truncate text-sm text-muted-foreground">
                  {connectedClinic.description}
                </p>
              )}
            </div>
          </div>
          <div className="grid gap-2 text-sm sm:grid-cols-2">
            {connectedClinic.address && (
              <Info icon={MapPin} text={connectedClinic.address} />
            )}
            {connectedClinic.phone && <Info icon={Phone} text={connectedClinic.phone} />}
            {connectedClinic.email && <Info icon={Mail} text={connectedClinic.email} />}
            {connectedClinic.website && <Info icon={Globe} text={connectedClinic.website} />}
          </div>
        </CardBody>
      </Card>

      {/* Quick actions */}
      <section className="space-y-4">
        <SectionHeader eyebrow="Manage" title="Quick actions" />
        <div className="grid gap-4 sm:grid-cols-2">
        <ActionCard
          icon={Stethoscope}
          title="Manage staff"
          caption="Invite and manage vets & receptionists"
          onClick={() => navigate('/staff')}
        />
        <ActionCard
          icon={Users}
          title="Patients"
          caption="View pet owners at your clinic"
          onClick={() => navigate('/patients')}
        />
        <ActionCard
          icon={MessageCircle}
          title="Messages"
          caption="Chat with pet owners"
          onClick={() => navigate('/chat')}
        />
          <ActionCard
            icon={Settings}
            title="Clinic settings"
            caption="Edit details and business hours"
            onClick={() => navigate('/settings')}
          />
        </div>
      </section>
    </div>
  );
}

function Info({ icon: Icon, text }: { icon: LucideIcon; text: string }) {
  return (
    <span className="inline-flex items-center gap-2 text-muted-foreground">
      <Icon size={15} className="shrink-0" /> <span className="truncate">{text}</span>
    </span>
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
      className="flex items-center gap-4 rounded-(--radius-lg) border border-border/50 bg-card p-5 text-left shadow-(--shadow-sm) transition-[transform,background-color,box-shadow] hover:-translate-y-0.5 hover:bg-secondary hover:shadow-(--shadow-md)"
    >
      <span className="grid h-12 w-12 shrink-0 place-items-center rounded-full bg-primary text-primary-foreground">
        <Icon size={20} />
      </span>
      <div className="min-w-0 flex-1">
        <p className="font-medium text-foreground">{title}</p>
        <p className="text-sm text-muted-foreground">{caption}</p>
      </div>
    </button>
  );
}
