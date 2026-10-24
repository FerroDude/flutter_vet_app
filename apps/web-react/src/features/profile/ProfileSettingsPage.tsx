import { useEffect, useState, type ReactNode } from 'react';
import { toast } from 'sonner';
import { LogOut, Stethoscope } from 'lucide-react';
import { type UserProfile } from '@vetplus/shared';
import { useAuth } from '@/auth/AuthProvider';
import { getUserProfile } from '@/lib/userService';
import { errorMessage, fullAddress, longDateFmt } from '@/lib/format';
import { lang, setLang, t, type Lang } from '@/i18n';
import { PageHeader } from '@/components/ui/PageHeader';
import { Card, CardBody } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { TextField } from '@/components/ui/TextField';

export function ProfileSettingsPage() {
  const { profile, role, updateProfile, signOutUser } = useAuth();
  const isClient = role === 'petOwner';

  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [address, setAddress] = useState('');
  const [postalCode, setPostalCode] = useState('');
  const [saving, setSaving] = useState(false);
  const [vet, setVet] = useState<UserProfile | null>(null);

  useEffect(() => {
    setName(profile?.displayName ?? '');
    setPhone(profile?.phone ?? '');
    setAddress(profile?.address ?? '');
    setPostalCode(profile?.postalCode ?? '');
  }, [profile]);

  // Clients see their vet's contact details (address for home visits).
  useEffect(() => {
    const vetId = profile?.vetId;
    if (!isClient || !vetId) return setVet(null);
    let active = true;
    void getUserProfile(vetId).then((v) => active && setVet(v));
    return () => {
      active = false;
    };
  }, [isClient, profile?.vetId]);

  const dirty =
    name.trim() !== (profile?.displayName ?? '') ||
    phone.trim() !== (profile?.phone ?? '') ||
    address.trim() !== (profile?.address ?? '') ||
    postalCode.trim() !== (profile?.postalCode ?? '');

  const displayName = profile?.displayName?.trim() || profile?.email || t('common.user');

  const save = async () => {
    setSaving(true);
    try {
      await updateProfile({
        displayName: name.trim(),
        phone: phone.trim(),
        address: address.trim(),
        postalCode: postalCode.trim(),
      });
      toast.success(t('profile.updated'));
    } catch (e) {
      toast.error(errorMessage(e, t('profile.updateFailed')));
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="mx-auto max-w-3xl">
      <PageHeader eyebrow={t('profile.account')} title={t('profile.title')} subtitle={t('profile.subtitle')} />

      <Card className="mb-6">
        <CardBody className="flex items-center gap-5">
          <div className="flex h-16 w-16 shrink-0 items-center justify-center rounded-full bg-primary-light text-2xl font-semibold text-primary">
            {displayName.charAt(0).toUpperCase()}
          </div>
          <div className="min-w-0 flex-1">
            <p className="truncate font-display text-2xl font-bold text-foreground">{displayName}</p>
            <p className="truncate text-sm text-muted-foreground">
              {isClient ? t('common.client') : t('common.vet')} · {profile?.email}
            </p>
          </div>
        </CardBody>
      </Card>

      <Section title={t('profile.data')}>
        <Card>
          <CardBody className="space-y-4">
            <TextField label={t('common.name')} value={name} onChange={(e) => setName(e.target.value)} />
            <div className="grid gap-4 sm:grid-cols-2">
              <TextField label={t('common.phone')} type="tel" value={phone} onChange={(e) => setPhone(e.target.value)} />
            </div>
            <div className="grid gap-4 sm:grid-cols-[minmax(0,1fr)_10rem]">
              <TextField
                label={t('profile.address')}
                autoComplete="street-address"
                value={address}
                onChange={(e) => setAddress(e.target.value)}
                hint={isClient ? undefined : t('profile.addressHint')}
              />
              <TextField
                label={t('profile.postalCode')}
                placeholder="1000-001"
                maxLength={12}
                autoComplete="postal-code"
                value={postalCode}
                onChange={(e) => setPostalCode(e.target.value)}
              />
            </div>
            <div className="flex items-center justify-between gap-4">
              <p className="text-xs text-muted-foreground">
                {profile?.createdAt ? t('profile.since', { date: longDateFmt.format(profile.createdAt) }) : ''}
              </p>
              <Button disabled={!dirty} loading={saving} onClick={() => void save()}>
                {t('common.save')}
              </Button>
            </div>
          </CardBody>
        </Card>
      </Section>

      <Section title={t('profile.language')}>
        <Card>
          <CardBody>
            <div className="flex gap-2">
              {(['pt', 'en'] as Lang[]).map((l) => (
                <Button
                  key={l}
                  variant={lang === l ? 'primary' : 'outline'}
                  onClick={() => {
                    if (l !== lang) setLang(l);
                  }}
                >
                  {l === 'pt' ? 'Português' : 'English'}
                </Button>
              ))}
            </div>
          </CardBody>
        </Card>
      </Section>

      {isClient && (
        <Section title={t('profile.yourVet')}>
          <Card>
            <CardBody className="flex items-start gap-4">
              <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-(--radius-md) bg-primary-light text-primary">
                <Stethoscope size={18} />
              </span>
              <div className="min-w-0 flex-1 space-y-1">
                <p className="break-words font-medium text-foreground">{vet?.displayName || t('common.vet')}</p>
                {vet?.phone && (
                  <a href={`tel:${vet.phone}`} className="block text-sm text-muted-foreground hover:text-foreground">
                    {vet.phone}
                  </a>
                )}
                {vet && fullAddress(vet) && (
                  <p className="break-words text-sm text-muted-foreground">{fullAddress(vet)}</p>
                )}
              </div>
            </CardBody>
          </Card>
        </Section>
      )}

      <Button variant="outline" onClick={() => void signOutUser()}>
        <LogOut size={16} /> {t('common.signOut')}
      </Button>
    </div>
  );
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="mb-6">
      <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">{title}</h2>
      {children}
    </section>
  );
}
