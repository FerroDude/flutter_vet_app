import { useEffect, useState } from 'react';
import { toast } from 'sonner';
import { Building2 } from 'lucide-react';
import { useAuth } from '@/auth/AuthProvider';
import { updateClinic } from '@/lib/clinicService';
import { PageHeader } from '@/components/ui/PageHeader';
import { Card, CardBody } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { TextField } from '@/components/ui/TextField';
import { Textarea } from '@/components/ui/Textarea';
import { EmptyState } from '@/components/ui/EmptyState';

const DAYS = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
] as const;
type Day = (typeof DAYS)[number];

interface DayHours {
  open: boolean;
  from: string;
  to: string;
}

function parseHours(raw: Record<string, unknown> | null | undefined): Record<Day, DayHours> {
  const out = {} as Record<Day, DayHours>;
  for (const d of DAYS) {
    const v = raw?.[d] as { open?: string; close?: string } | undefined;
    out[d] = v
      ? { open: true, from: v.open ?? '09:00', to: v.close ?? '17:00' }
      : { open: false, from: '09:00', to: '17:00' };
  }
  return out;
}

function hoursToFirestore(hours: Record<Day, DayHours>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const d of DAYS) {
    if (hours[d].open) out[d] = { open: hours[d].from, close: hours[d].to };
  }
  return out;
}

export function ClinicSettingsPage() {
  const { connectedClinic, refreshProfile } = useAuth();

  const [name, setName] = useState('');
  const [address, setAddress] = useState('');
  const [phone, setPhone] = useState('');
  const [email, setEmail] = useState('');
  const [website, setWebsite] = useState('');
  const [description, setDescription] = useState('');
  const [hours, setHours] = useState<Record<Day, DayHours>>(() => parseHours(null));
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!connectedClinic) return;
    setName(connectedClinic.name ?? '');
    setAddress(connectedClinic.address ?? '');
    setPhone(connectedClinic.phone ?? '');
    setEmail(connectedClinic.email ?? '');
    setWebsite(connectedClinic.website ?? '');
    setDescription(connectedClinic.description ?? '');
    setHours(parseHours(connectedClinic.businessHours));
  }, [connectedClinic]);

  if (!connectedClinic) {
    return (
      <div>
        <PageHeader title="Clinic settings" />
        <EmptyState
          icon={<Building2 size={36} />}
          title="No clinic"
          description="Your account isn't linked to a clinic yet."
        />
      </div>
    );
  }

  const setDay = (d: Day, patch: Partial<DayHours>) =>
    setHours((h) => ({ ...h, [d]: { ...h[d], ...patch } }));

  const save = async () => {
    if (!name.trim()) {
      toast.error('Clinic name is required.');
      return;
    }
    setSaving(true);
    try {
      await updateClinic(connectedClinic.id, {
        name,
        address,
        phone,
        email,
        website,
        description,
        businessHours: hoursToFirestore(hours),
      });
      await refreshProfile();
      toast.success('Clinic updated');
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not save clinic');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="mx-auto max-w-3xl">
      <PageHeader eyebrow="Configuration" title="Clinic settings" subtitle="Manage your clinic's details and hours." />

      <Card className="mb-6">
        <CardBody className="space-y-4">
          <TextField label="Clinic name" value={name} onChange={(e) => setName(e.target.value)} />
          <TextField label="Address" value={address} onChange={(e) => setAddress(e.target.value)} />
          <div className="grid gap-4 sm:grid-cols-2">
            <TextField label="Phone" value={phone} onChange={(e) => setPhone(e.target.value)} />
            <TextField label="Email" value={email} onChange={(e) => setEmail(e.target.value)} />
          </div>
          <TextField label="Website" value={website} onChange={(e) => setWebsite(e.target.value)} />
          <Textarea
            label="Description"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
          />
        </CardBody>
      </Card>

      <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
        Business hours
      </h2>
      <Card className="mb-6">
        <CardBody className="space-y-2">
          {DAYS.map((d) => (
            <div key={d} className="flex flex-wrap items-center gap-3">
              <label className="flex w-32 shrink-0 items-center gap-2 text-sm font-medium capitalize text-foreground">
                <input
                  type="checkbox"
                  checked={hours[d].open}
                  onChange={(e) => setDay(d, { open: e.target.checked })}
                  className="h-4 w-4 rounded border-input accent-[hsl(var(--primary))]"
                />
                {d}
              </label>
              {hours[d].open ? (
                <div className="flex items-center gap-2">
                  <input
                    type="time"
                    value={hours[d].from}
                    onChange={(e) => setDay(d, { from: e.target.value })}
                    className="h-10 rounded-(--radius-md) border border-input bg-card px-2 text-sm text-foreground focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring"
                  />
                  <span className="text-muted-foreground">–</span>
                  <input
                    type="time"
                    value={hours[d].to}
                    onChange={(e) => setDay(d, { to: e.target.value })}
                    className="h-10 rounded-(--radius-md) border border-input bg-card px-2 text-sm text-foreground focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring"
                  />
                </div>
              ) : (
                <span className="text-sm text-muted-foreground">Closed</span>
              )}
            </div>
          ))}
        </CardBody>
      </Card>

      <div className="flex justify-end">
        <Button loading={saving} onClick={() => void save()}>
          Save changes
        </Button>
      </div>
    </div>
  );
}
