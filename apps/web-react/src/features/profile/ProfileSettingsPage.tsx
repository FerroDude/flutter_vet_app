import { useEffect, useMemo, useState } from 'react';
import { toast } from 'sonner';
import {
  Building2,
  LogOut,
  Trash2,
  Search,
  PawPrint,
  Pill,
  Activity,
  Bell,
} from 'lucide-react';
import { type Clinic } from '@vetplus/shared';
import { useAuth, type Role } from '@/auth/AuthProvider';
import { petsQuery, mapPet, type Pet } from '@/lib/petService';
import { useAllMedications } from '@/lib/useAllMedications';
import { useAllSymptoms } from '@/lib/useAllSymptoms';
import { useCollection } from '@/lib/useFirestore';
import { searchClinics } from '@/lib/userService';
import { isPushSupported, pushPermission, enablePush, disablePush } from '@/lib/messaging';
import { useTheme, type ThemeMode } from '@/lib/theme';
import { PageHeader } from '@/components/ui/PageHeader';
import { Card, CardBody } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { TextField } from '@/components/ui/TextField';
import { Dialog } from '@/components/ui/Dialog';

const ROLE_LABEL: Record<Role, string> = {
  petOwner: 'Pet Owner',
  vet: 'Veterinarian',
  clinicAdmin: 'Clinic Administrator',
  receptionist: 'Receptionist',
  appOwner: 'App Owner',
  unknown: 'User',
};

const dateFmt = new Intl.DateTimeFormat(undefined, {
  year: 'numeric',
  month: 'long',
  day: 'numeric',
});

export function ProfileSettingsPage() {
  const {
    firebaseUser,
    profile,
    role,
    connectedClinic,
    updateProfile,
    connectToClinic,
    disconnectFromClinic,
    deleteAccount,
    signOutUser,
  } = useAuth();
  const uid = firebaseUser?.uid ?? '';
  const isOwner = role === 'petOwner';

  const petQ = useMemo(() => (uid ? petsQuery(uid) : null), [uid]);
  const { data: pets } = useCollection<Pet>(petQ, mapPet);
  const meds = useAllMedications(uid);
  const symptoms = useAllSymptoms(uid);

  const [theme, setTheme] = useTheme();

  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [address, setAddress] = useState('');
  const [savingProfile, setSavingProfile] = useState(false);

  useEffect(() => {
    setName(profile?.displayName ?? '');
    setPhone(profile?.phone ?? '');
    setAddress(profile?.address ?? '');
  }, [profile]);

  const dirty =
    name.trim() !== (profile?.displayName ?? '') ||
    phone.trim() !== (profile?.phone ?? '') ||
    address.trim() !== (profile?.address ?? '');

  const [clinicDialogOpen, setClinicDialogOpen] = useState(false);
  const [disconnectOpen, setDisconnectOpen] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [deleting, setDeleting] = useState(false);

  const [pushSupported, setPushSupported] = useState<boolean | null>(null);
  const [pushEnabled, setPushEnabled] = useState<boolean>(Boolean(profile?.fcmToken));
  const [pushBusy, setPushBusy] = useState(false);

  useEffect(() => {
    void isPushSupported().then(setPushSupported);
  }, []);
  useEffect(() => {
    setPushEnabled(Boolean(profile?.fcmToken));
  }, [profile]);

  const togglePush = async () => {
    if (!uid) return;
    setPushBusy(true);
    try {
      if (pushEnabled) {
        await disablePush(uid);
        setPushEnabled(false);
        toast.success('Notifications turned off');
      } else {
        const token = await enablePush(uid);
        if (token) {
          setPushEnabled(true);
          toast.success('Notifications enabled');
        } else {
          toast.error('Could not enable notifications. Check your browser permission.');
        }
      }
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not update notifications');
    } finally {
      setPushBusy(false);
    }
  };

  const displayName = profile?.displayName?.trim() || profile?.email || 'User';
  const initial = displayName.charAt(0).toUpperCase() || 'U';

  const saveProfile = async () => {
    setSavingProfile(true);
    try {
      await updateProfile({
        displayName: name.trim(),
        phone: phone.trim(),
        address: address.trim(),
      });
      toast.success('Profile updated');
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not update profile');
    } finally {
      setSavingProfile(false);
    }
  };

  const onConnect = async (clinic: Clinic) => {
    try {
      await connectToClinic(clinic.id);
      toast.success(`Connected to ${clinic.name}`);
      setClinicDialogOpen(false);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not connect');
    }
  };

  const onDisconnect = async () => {
    try {
      await disconnectFromClinic();
      toast.success('Disconnected from clinic');
      setDisconnectOpen(false);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not disconnect');
    }
  };

  const onDelete = async () => {
    setDeleting(true);
    try {
      await deleteAccount();
      toast.success('Account deleted');
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not delete account');
      setDeleting(false);
    }
  };

  return (
    <div className="mx-auto max-w-3xl">
      <PageHeader eyebrow="Account" title="Profile & settings" subtitle="Manage your account and preferences." />

      {/* Identity + stats */}
      <Card className="mb-6">
        <CardBody className="flex flex-wrap items-center gap-5">
          <div className="flex h-16 w-16 items-center justify-center rounded-full bg-primary-light text-2xl font-semibold text-primary">
            {initial}
          </div>
          <div className="min-w-0 flex-1">
            <p className="truncate font-display text-2xl font-bold text-foreground">{displayName}</p>
            <p className="truncate text-sm text-muted-foreground">{profile?.email}</p>
          </div>
          {isOwner && (
            <div className="flex gap-6">
              <Stat icon={<PawPrint size={16} />} value={pets.length} label="Pets" />
              <Stat icon={<Pill size={16} />} value={meds.length} label="Meds" />
              <Stat icon={<Activity size={16} />} value={symptoms.length} label="Symptoms" />
            </div>
          )}
        </CardBody>
      </Card>

      {/* Edit profile */}
      <Section title="Profile">
        <Card>
          <CardBody className="space-y-4">
            <TextField label="Display name" value={name} onChange={(e) => setName(e.target.value)} />
            <div className="grid gap-4 sm:grid-cols-2">
              <TextField label="Phone" value={phone} onChange={(e) => setPhone(e.target.value)} />
              <TextField label="Address" value={address} onChange={(e) => setAddress(e.target.value)} />
            </div>
            <div className="flex justify-end">
              <Button disabled={!dirty} loading={savingProfile} onClick={() => void saveProfile()}>
                Save changes
              </Button>
            </div>
          </CardBody>
        </Card>
      </Section>

      {/* Connected clinic (pet owners manage their own clinic link) */}
      {isOwner && (
        <Section title="Clinic">
          <Card>
            <CardBody className="flex flex-wrap items-center gap-4">
              <span className="flex h-10 w-10 items-center justify-center rounded-(--radius-md) bg-primary-light text-primary">
                <Building2 size={18} />
              </span>
              <div className="min-w-0 flex-1">
                <p className="font-medium text-foreground">
                  {connectedClinic?.name ?? 'No clinic connected'}
                </p>
                {connectedClinic?.address && (
                  <p className="truncate text-sm text-muted-foreground">{connectedClinic.address}</p>
                )}
              </div>
              <div className="flex gap-2">
                <Button variant="outline" onClick={() => setClinicDialogOpen(true)}>
                  {connectedClinic ? 'Change' : 'Connect'}
                </Button>
                {connectedClinic && (
                  <Button variant="ghost" onClick={() => setDisconnectOpen(true)}>
                    Disconnect
                  </Button>
                )}
              </div>
            </CardBody>
          </Card>
        </Section>
      )}

      {/* Preferences */}
      <Section title="Appearance">
        <Card>
          <CardBody className="flex flex-wrap items-center justify-between gap-4">
            <div>
              <p className="font-medium text-foreground">Theme</p>
              <p className="text-sm text-muted-foreground">Choose light, dark, or match your system.</p>
            </div>
            <select
              aria-label="Theme"
              value={theme}
              onChange={(e) => setTheme(e.target.value as ThemeMode)}
              className="h-11 w-40 rounded-(--radius-md) border border-input bg-card px-3.5 text-sm text-foreground focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring"
            >
              <option value="system">System</option>
              <option value="light">Light</option>
              <option value="dark">Dark</option>
            </select>
          </CardBody>
        </Card>
      </Section>

      {/* Notifications */}
      <Section title="Notifications">
        <Card>
          <CardBody className="flex flex-wrap items-center justify-between gap-4">
            <div className="flex items-start gap-3">
              <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-(--radius-md) bg-primary-light text-primary">
                <Bell size={18} />
              </span>
              <div>
                <p className="font-medium text-foreground">Push notifications</p>
                <p className="text-sm text-muted-foreground">
                  {pushSupported === null
                    ? 'Checking browser support…'
                    : !pushSupported
                      ? 'Not supported in this browser.'
                      : pushPermission() === 'denied'
                        ? 'Blocked in your browser settings — allow notifications to turn these on.'
                        : 'Get alerts for new messages and appointment updates.'}
                </p>
              </div>
            </div>
            {pushSupported && pushPermission() !== 'denied' && (
              <Button
                variant={pushEnabled ? 'outline' : 'primary'}
                loading={pushBusy}
                onClick={() => void togglePush()}
              >
                {pushEnabled ? 'Turn off' : 'Enable'}
              </Button>
            )}
          </CardBody>
        </Card>
      </Section>

      {/* Account info */}
      <Section title="Account">
        <Card>
          <CardBody className="space-y-3">
            <Row label="Email" value={profile?.email ?? '—'} />
            <Row label="Account type" value={ROLE_LABEL[role]} />
            <Row
              label="Member since"
              value={profile?.createdAt ? dateFmt.format(profile.createdAt) : '—'}
            />
          </CardBody>
        </Card>
      </Section>

      {/* Danger zone */}
      <div className="mt-8 flex flex-wrap gap-3">
        <Button variant="outline" onClick={() => void signOutUser()}>
          <LogOut size={16} /> Sign out
        </Button>
        <Button variant="destructive" onClick={() => setDeleteOpen(true)}>
          <Trash2 size={16} /> Delete account
        </Button>
      </div>

      <ClinicConnectDialog
        open={clinicDialogOpen}
        onClose={() => setClinicDialogOpen(false)}
        currentClinicId={connectedClinic?.id}
        onPick={(c) => void onConnect(c)}
      />

      <Dialog
        open={disconnectOpen}
        onClose={() => setDisconnectOpen(false)}
        title="Disconnect clinic"
        description={
          connectedClinic
            ? `Disconnect from ${connectedClinic.name}? You can reconnect anytime.`
            : ''
        }
        footer={
          <>
            <Button variant="outline" onClick={() => setDisconnectOpen(false)}>
              Cancel
            </Button>
            <Button variant="destructive" onClick={() => void onDisconnect()}>
              Disconnect
            </Button>
          </>
        }
      />

      <Dialog
        open={deleteOpen}
        onClose={() => (deleting ? undefined : setDeleteOpen(false))}
        title="Delete account"
        description="This permanently deletes your profile and associated data. This cannot be undone."
        footer={
          <>
            <Button variant="outline" disabled={deleting} onClick={() => setDeleteOpen(false)}>
              Cancel
            </Button>
            <Button variant="destructive" loading={deleting} onClick={() => void onDelete()}>
              Delete account
            </Button>
          </>
        }
      />
    </div>
  );
}

function Stat({ icon, value, label }: { icon: React.ReactNode; value: number; label: string }) {
  return (
    <div className="text-center">
      <p className="flex items-center justify-center gap-1 font-display text-xl font-bold tabular-nums text-foreground">
        {value}
      </p>
      <p className="flex items-center justify-center gap-1 text-xs text-muted-foreground">
        {icon}
        {label}
      </p>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="mb-6">
      <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
        {title}
      </h2>
      {children}
    </section>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-4">
      <span className="text-sm text-muted-foreground">{label}</span>
      <span className="truncate text-sm font-medium text-foreground">{value}</span>
    </div>
  );
}

function ClinicConnectDialog({
  open,
  onClose,
  currentClinicId,
  onPick,
}: {
  open: boolean;
  onClose: () => void;
  currentClinicId?: string;
  onPick: (clinic: Clinic) => void;
}) {
  const [q, setQ] = useState('');
  const [results, setResults] = useState<Clinic[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!open) return;
    let active = true;
    setLoading(true);
    searchClinics(q)
      .then((list) => {
        if (active) setResults(list.filter((c) => c.id !== currentClinicId));
      })
      .catch(() => {
        if (active) setResults([]);
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, [open, q, currentClinicId]);

  return (
    <Dialog open={open} onClose={onClose} title="Select a clinic">
      <div className="space-y-3">
        <div className="relative">
          <Search
            size={16}
            className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground"
          />
          <input
            type="text"
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Search clinics…"
            className="h-11 w-full rounded-(--radius-md) border border-input bg-card pl-9 pr-3 text-sm text-foreground focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring"
          />
        </div>
        <div className="max-h-72 space-y-2 overflow-y-auto">
          {loading ? (
            <p className="py-6 text-center text-sm text-muted-foreground">Searching…</p>
          ) : results.length === 0 ? (
            <p className="py-6 text-center text-sm text-muted-foreground">No clinics found.</p>
          ) : (
            results.map((c) => (
              <button
                key={c.id}
                type="button"
                onClick={() => onPick(c)}
                className="flex w-full items-center gap-3 rounded-(--radius-md) border border-border p-3 text-left transition-colors hover:bg-secondary"
              >
                <span className="flex h-9 w-9 items-center justify-center rounded-(--radius-md) bg-primary-light text-primary">
                  <Building2 size={16} />
                </span>
                <span className="min-w-0">
                  <span className="block truncate font-medium text-foreground">{c.name}</span>
                  {c.address && (
                    <span className="block truncate text-xs text-muted-foreground">{c.address}</span>
                  )}
                </span>
              </button>
            ))
          )}
        </div>
      </div>
    </Dialog>
  );
}
