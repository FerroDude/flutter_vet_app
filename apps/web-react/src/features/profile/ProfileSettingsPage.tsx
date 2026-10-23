import { useEffect, useMemo, useState } from 'react';
import { toast } from 'sonner';
import {
  LogOut,
  Trash2,
  PawPrint,
  Pill,
  Activity,
  Bell,
  Stethoscope,
} from 'lucide-react';
import { type UserProfile } from '@vetplus/shared';
import { useAuth, type Role } from '@/auth/AuthProvider';
import { petsQuery, mapPet, type Pet } from '@/lib/petService';
import { useAllMedications } from '@/lib/useAllMedications';
import { useAllSymptoms } from '@/lib/useAllSymptoms';
import { useCollection } from '@/lib/useFirestore';
import { getUserProfile } from '@/lib/userService';
import { isPushSupported, pushPermission, enablePush, disablePush } from '@/lib/messaging';
import { PageHeader } from '@/components/ui/PageHeader';
import { Card, CardBody } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { TextField } from '@/components/ui/TextField';
import { Dialog } from '@/components/ui/Dialog';

const ROLE_LABEL: Record<Role, string> = {
  petOwner: 'Cliente',
  vet: 'Veterinária',
  clinicAdmin: 'Administrador',
  receptionist: 'Receção',
  unknown: 'Utilizador',
};

const dateFmt = new Intl.DateTimeFormat('pt-PT', {
  year: 'numeric',
  month: 'long',
  day: 'numeric',
});

export function ProfileSettingsPage() {
  const {
    firebaseUser,
    profile,
    role,
    updateProfile,
    deleteAccount,
    signOutUser,
  } = useAuth();
  const uid = firebaseUser?.uid ?? '';
  const isOwner = role === 'petOwner';

  const petQ = useMemo(() => (uid ? petsQuery(uid) : null), [uid]);
  const { data: pets } = useCollection<Pet>(petQ, mapPet);
  const meds = useAllMedications(uid);
  const symptoms = useAllSymptoms(uid);

  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [address, setAddress] = useState('');
  const [savingProfile, setSavingProfile] = useState(false);
  const [vet, setVet] = useState<UserProfile | null>(null);

  useEffect(() => {
    setName(profile?.displayName ?? '');
    setPhone(profile?.phone ?? '');
    setAddress(profile?.address ?? '');
  }, [profile]);

  useEffect(() => {
    const vetId = profile?.vetId;
    if (!isOwner || !vetId) {
      setVet(null);
      return;
    }
    let active = true;
    void getUserProfile(vetId).then((found) => {
      if (active) setVet(found);
    });
    return () => {
      active = false;
    };
  }, [isOwner, profile?.vetId]);

  const dirty =
    name.trim() !== (profile?.displayName ?? '') ||
    phone.trim() !== (profile?.phone ?? '') ||
    address.trim() !== (profile?.address ?? '');

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
        toast.success('Notificações desligadas');
      } else {
        const token = await enablePush(uid);
        if (token) {
          setPushEnabled(true);
          toast.success('Notificações ligadas');
        } else {
          toast.error('Não foi possível ligar as notificações. Verifique a permissão do browser.');
        }
      }
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Não foi possível atualizar as notificações');
    } finally {
      setPushBusy(false);
    }
  };

  const displayName = profile?.displayName?.trim() || profile?.email || 'Utilizador';
  const initial = displayName.charAt(0).toUpperCase() || '?';

  const saveProfile = async () => {
    setSavingProfile(true);
    try {
      await updateProfile({
        displayName: name.trim(),
        phone: phone.trim(),
        address: address.trim(),
      });
      toast.success('Perfil atualizado');
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Não foi possível atualizar o perfil');
    } finally {
      setSavingProfile(false);
    }
  };

  const onDelete = async () => {
    setDeleting(true);
    try {
      await deleteAccount();
      toast.success('Conta apagada');
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Não foi possível apagar a conta');
      setDeleting(false);
    }
  };

  return (
    <div className="mx-auto max-w-3xl">
      <PageHeader eyebrow="Conta" title="Perfil" subtitle="Os seus dados e preferências." />

      {/* Identity + stats */}
      <Card className="mb-6">
        <CardBody className="flex flex-wrap items-center gap-5">
          <div className="flex h-16 w-16 shrink-0 items-center justify-center rounded-full bg-primary-light text-2xl font-semibold text-primary">
            {initial}
          </div>
          <div className="min-w-0 flex-1">
            <p className="truncate font-display text-2xl font-bold text-foreground">{displayName}</p>
            <p className="truncate text-sm text-muted-foreground">{profile?.email}</p>
          </div>
          {isOwner && (
            <div className="flex gap-6">
              <Stat icon={<PawPrint size={16} />} value={pets.length} label="Animais" />
              <Stat icon={<Pill size={16} />} value={meds.length} label="Medicação" />
              <Stat icon={<Activity size={16} />} value={symptoms.length} label="Sintomas" />
            </div>
          )}
        </CardBody>
      </Card>

      {/* Edit profile */}
      <Section title="Dados">
        <Card>
          <CardBody className="space-y-4">
            <TextField label="Nome" value={name} onChange={(e) => setName(e.target.value)} />
            <div className="grid gap-4 sm:grid-cols-2">
              <TextField label="Telefone" value={phone} onChange={(e) => setPhone(e.target.value)} />
              <TextField label="Morada" value={address} onChange={(e) => setAddress(e.target.value)} />
            </div>
            <div className="flex justify-end">
              <Button disabled={!dirty} loading={savingProfile} onClick={() => void saveProfile()}>
                Guardar
              </Button>
            </div>
          </CardBody>
        </Card>
      </Section>

      {isOwner && (
        <Section title="Veterinária">
          <Card>
            <CardBody className="flex flex-wrap items-start gap-4">
              <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-(--radius-md) bg-primary-light text-primary">
                <Stethoscope size={18} />
              </span>
              <div className="min-w-0 flex-1 space-y-1">
                <p className="break-words font-medium text-foreground">{vet?.displayName || 'A sua veterinária'}</p>
                {vet?.phone && (
                  <a href={`tel:${vet.phone}`} className="block text-sm text-muted-foreground hover:text-foreground">
                    {vet.phone}
                  </a>
                )}
                {vet?.address && (
                  <p className="break-words text-sm text-muted-foreground">{vet.address}</p>
                )}
                {!vet && (
                  <p className="text-sm text-muted-foreground">
                    A morada aparece aqui para as visitas ao domicílio.
                  </p>
                )}
              </div>
            </CardBody>
          </Card>
        </Section>
      )}

      {/* Notifications */}
      <Section title="Notificações">
        <Card>
          <CardBody className="flex flex-wrap items-center justify-between gap-4">
            <div className="flex items-start gap-3">
              <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-(--radius-md) bg-primary-light text-primary">
                <Bell size={18} />
              </span>
              <div>
                <p className="font-medium text-foreground">Notificações</p>
                <p className="text-sm text-muted-foreground">
                  {pushSupported === null
                    ? 'A verificar o browser…'
                    : !pushSupported
                      ? 'Este browser não suporta notificações.'
                      : pushPermission() === 'denied'
                        ? 'Bloqueadas nas definições do browser. Autorize para as ligar.'
                        : 'Avisos de mensagens novas e de marcações.'}
                </p>
              </div>
            </div>
            {pushSupported && pushPermission() !== 'denied' && (
              <Button
                variant={pushEnabled ? 'outline' : 'primary'}
                loading={pushBusy}
                onClick={() => void togglePush()}
              >
                {pushEnabled ? 'Desligar' : 'Ligar'}
              </Button>
            )}
          </CardBody>
        </Card>
      </Section>

      {/* Account info */}
      <Section title="Conta">
        <Card>
          <CardBody className="space-y-3">
            <Row label="Email" value={profile?.email ?? '—'} />
            <Row label="Tipo de conta" value={ROLE_LABEL[role]} />
            <Row
              label="Membro desde"
              value={profile?.createdAt ? dateFmt.format(profile.createdAt) : '—'}
            />
          </CardBody>
        </Card>
      </Section>

      {/* Danger zone */}
      <div className="mt-8 flex flex-wrap gap-3">
        <Button variant="outline" onClick={() => void signOutUser()}>
          <LogOut size={16} /> Terminar sessão
        </Button>
        <Button variant="destructive" onClick={() => setDeleteOpen(true)}>
          <Trash2 size={16} /> Apagar conta
        </Button>
      </div>

      <Dialog
        open={deleteOpen}
        onClose={() => (deleting ? undefined : setDeleteOpen(false))}
        title="Apagar conta"
        description="Apaga o perfil e os dados associados. Não dá para desfazer."
        footer={
          <>
            <Button variant="outline" disabled={deleting} onClick={() => setDeleteOpen(false)}>
              Cancelar
            </Button>
            <Button variant="destructive" loading={deleting} onClick={() => void onDelete()}>
              Apagar conta
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
      <span className="shrink-0 text-sm text-muted-foreground">{label}</span>
      <span className="min-w-0 truncate text-sm font-medium text-foreground">{value}</span>
    </div>
  );
}

