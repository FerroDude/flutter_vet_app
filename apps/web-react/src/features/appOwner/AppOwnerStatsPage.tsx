import { useMemo } from 'react';
import {
  Building2,
  CheckCircle2,
  PawPrint,
  Stethoscope,
  Headset,
  Shield,
  Users,
  type LucideIcon,
} from 'lucide-react';
import { type Clinic, type UserProfile, UserType } from '@vetplus/shared';
import { useCollection } from '@/lib/useFirestore';
import { allClinicsQuery, mapClinic, allUsersQuery, mapPatient } from '@/lib/clinicService';
import { PageHeader } from '@/components/ui/PageHeader';
import { Card, CardBody } from '@/components/ui/Card';

export function AppOwnerStatsPage() {
  const { data: clinics } = useCollection<Clinic>(allClinicsQuery(), mapClinic);
  const { data: usersRaw } = useCollection<UserProfile>(allUsersQuery(), mapPatient);

  const users = useMemo(() => usersRaw.filter((u) => !u.id.startsWith('temp_')), [usersRaw]);

  const counts = useMemo(() => {
    const c = {
      petOwners: 0,
      vets: 0,
      admins: 0,
      receptionists: 0,
      appOwners: 0,
    };
    for (const u of users) {
      switch (u.userType) {
        case UserType.vet:
          c.vets++;
          break;
        case UserType.clinicAdmin:
          c.admins++;
          break;
        case UserType.appOwner:
          c.appOwners++;
          break;
        case UserType.receptionist:
          c.receptionists++;
          break;
        default:
          c.petOwners++;
      }
    }
    return c;
  }, [users]);

  const activeClinics = useMemo(() => clinics.filter((c) => c.isActive).length, [clinics]);

  return (
    <div>
      <PageHeader eyebrow="Platform" title="Analytics" subtitle="Platform-wide statistics." />

      <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
        Clinics
      </h2>
      <div className="mb-6 grid gap-4 sm:grid-cols-2">
        <Stat icon={Building2} label="Total clinics" value={clinics.length} />
        <Stat icon={CheckCircle2} label="Active clinics" value={activeClinics} />
      </div>

      <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
        Users ({users.length})
      </h2>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <Stat icon={PawPrint} label="Pet owners" value={counts.petOwners} />
        <Stat icon={Stethoscope} label="Veterinarians" value={counts.vets} />
        <Stat icon={Headset} label="Receptionists" value={counts.receptionists} />
        <Stat icon={Shield} label="Clinic admins" value={counts.admins} />
        <Stat icon={Users} label="App owners" value={counts.appOwners} />
      </div>
    </div>
  );
}

function Stat({ icon: Icon, label, value }: { icon: LucideIcon; label: string; value: number }) {
  return (
    <Card>
      <CardBody className="flex items-center gap-4">
        <span className="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-primary-light text-primary">
          <Icon size={20} />
        </span>
        <div>
          <p className="font-display text-2xl font-bold tabular-nums text-foreground">{value}</p>
          <p className="text-sm text-muted-foreground">{label}</p>
        </div>
      </CardBody>
    </Card>
  );
}
