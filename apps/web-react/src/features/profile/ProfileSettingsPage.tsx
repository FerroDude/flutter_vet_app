import { useEffect, useState, type ReactNode } from 'react';
import { toast } from 'sonner';
import { CalendarCheck, LogOut, RefreshCw, Stethoscope, Unlink } from 'lucide-react';
import { type UserProfile } from '@vetplus/shared';
import { useAuth } from '@/auth/AuthProvider';
import { getUserProfile } from '@/lib/userService';
import {
  connectGcal,
  disconnectGcal,
  gcalEnabled,
  syncGcal,
  useGcalStatus,
} from '@/lib/gcalService';
import { dateTimeFmt } from '@/lib/format';
import { useConfirm } from '@/components/ui/Confirm';
import {
  alertsMuted,
  notificationPermission,
  notificationsMuted,
  requestNotifications,
  setAlertsMuted,
  setNotificationsMuted,
} from '@/lib/notifications';
import { errorMessage, fullAddress, longDateFmt } from '@/lib/format';
import {
  ClientDetailsFields,
  detailsFromDraft,
  draftFromProfile,
  type ClientDetailsDraft,
} from './ClientDetailsFields';
import { lang, setLang, t, type Lang } from '@/i18n';
import { PageHeader } from '@/components/ui/PageHeader';
import { Card, CardBody } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { TextField } from '@/components/ui/TextField';

export function ProfileSettingsPage() {
  const { profile, role, updateProfile, signOutUser, firebaseUser } = useAuth();
  const isClient = role === 'petOwner';
  const confirm = useConfirm();
  const { data: gcal } = useGcalStatus(role === 'vet' ? (firebaseUser?.uid ?? '') : '');
  const [gcalBusy, setGcalBusy] = useState<'' | 'connect' | 'sync' | 'disconnect'>('');

  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [address, setAddress] = useState('');
  const [postalCode, setPostalCode] = useState('');
  const [details, setDetails] = useState<ClientDetailsDraft>(() => draftFromProfile(null));
  const [saving, setSaving] = useState(false);
  const [vet, setVet] = useState<UserProfile | null>(null);
  const [notifPerm, setNotifPerm] = useState(notificationPermission());
  const [notifMuted, setNotifMuted] = useState(notificationsMuted());
  const [inAppMuted, setInAppMuted] = useState(alertsMuted());

  useEffect(() => {
    setName(profile?.displayName ?? '');
    setPhone(profile?.phone ?? '');
    setAddress(profile?.address ?? '');
    setPostalCode(profile?.postalCode ?? '');
    setDetails(draftFromProfile(profile));
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
    (isClient
      ? JSON.stringify(details) !== JSON.stringify(draftFromProfile(profile))
      : phone.trim() !== (profile?.phone ?? '') ||
        address.trim() !== (profile?.address ?? '') ||
        postalCode.trim() !== (profile?.postalCode ?? ''));

  const displayName = profile?.displayName?.trim() || profile?.email || t('common.user');

  const save = async () => {
    setSaving(true);
    try {
      await updateProfile({
        displayName: name.trim(),
        ...(isClient
          ? detailsFromDraft(details)
          : {
              phone: phone.trim(),
              address: address.trim(),
              postalCode: postalCode.trim(),
            }),
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
            {isClient ? (
              <ClientDetailsFields draft={details} onChange={setDetails} />
            ) : (
              <>
                <div className="grid gap-4 sm:grid-cols-2">
                  <TextField label={t('common.phone')} type="tel" value={phone} onChange={(e) => setPhone(e.target.value)} />
                </div>
                <div className="grid gap-4 sm:grid-cols-[minmax(0,1fr)_10rem]">
                  <TextField
                    label={t('profile.address')}
                    autoComplete="street-address"
                    value={address}
                    onChange={(e) => setAddress(e.target.value)}
                    hint={t('profile.addressHint')}
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
              </>
            )}
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

      <Section title={t('notif.title')}>
        <Card>
          <CardBody className="space-y-2">
            <label className="flex w-fit items-center gap-2 text-sm text-muted-foreground">
              <input
                type="checkbox"
                checked={!inAppMuted}
                onChange={(e) => {
                  setAlertsMuted(!e.target.checked);
                  setInAppMuted(!e.target.checked);
                }}
                className="h-4 w-4 accent-[hsl(var(--primary))]"
              />
              {t('alerts.showInApp')}
            </label>
            {notifPerm === 'unsupported' ? (
              <p className="text-sm text-muted-foreground">{t('notif.unsupported')}</p>
            ) : notifPerm === 'granted' ? (
              <label className="inline-flex items-center gap-2 text-sm text-muted-foreground">
                <input
                  type="checkbox"
                  checked={!notifMuted}
                  onChange={(e) => {
                    setNotificationsMuted(!e.target.checked);
                    setNotifMuted(!e.target.checked);
                  }}
                  className="h-4 w-4 accent-[hsl(var(--primary))]"
                />
                {t('notif.showOnDevice')}
              </label>
            ) : notifPerm === 'denied' ? (
              <p className="text-sm text-muted-foreground">{t('notif.denied')}</p>
            ) : (
              <Button
                onClick={() =>
                  void requestNotifications().then((p) => {
                    if (p === 'granted') {
                      setNotificationsMuted(false);
                      setNotifMuted(false);
                    }
                    setNotifPerm(p);
                  })
                }
              >
                {t('notif.enable')}
              </Button>
            )}
            {notifPerm !== 'unsupported' && (
              <p className="text-xs text-muted-foreground">{t('notif.tabOnly')}</p>
            )}
          </CardBody>
        </Card>
      </Section>

      {gcalEnabled && !isClient && (
        <Section title="Google Calendar">
          <Card>
            <CardBody className="space-y-3">
              {!gcal?.connected ? (
                <>
                  <p className="text-sm text-muted-foreground">
                    {gcal?.lastError === 'revoked' ? t('gcal.revoked') : t('gcal.hint')}
                  </p>
                  <div>
                    <Button
                      loading={gcalBusy === 'connect'}
                      onClick={() => {
                        setGcalBusy('connect');
                        void connectGcal()
                          .then((r) => toast.success(t('gcal.syncedCount', { count: r.synced })))
                          .catch((e) => toast.error(errorMessage(e)))
                          .finally(() => setGcalBusy(''));
                      }}
                    >
                      <CalendarCheck size={16} />{' '}
                      {gcal?.lastError === 'revoked' ? t('gcal.reconnect') : t('gcal.connect')}
                    </Button>
                  </div>
                </>
              ) : (
                <>
                  <p className="text-sm text-foreground">
                    {t('gcal.connected', { email: gcal.googleEmail || '—' })}
                  </p>
                  {gcal.lastSyncAt && (
                    <p className="text-xs text-muted-foreground">
                      {t('gcal.lastSync', { date: dateTimeFmt.format(gcal.lastSyncAt) })}
                    </p>
                  )}
                  <div className="flex flex-wrap gap-2">
                    <Button
                      variant="outline"
                      loading={gcalBusy === 'sync'}
                      onClick={() => {
                        setGcalBusy('sync');
                        void syncGcal()
                          .then((n) => toast.success(t('gcal.syncedCount', { count: n })))
                          .catch((e) => toast.error(errorMessage(e)))
                          .finally(() => setGcalBusy(''));
                      }}
                    >
                      <RefreshCw size={16} /> {t('gcal.syncAll')}
                    </Button>
                    <Button
                      variant="outline"
                      loading={gcalBusy === 'disconnect'}
                      onClick={() => {
                        void confirm({
                          title: t('gcal.disconnectTitle'),
                          description: t('gcal.disconnectDesc'),
                          confirmLabel: t('gcal.disconnect'),
                          danger: true,
                        }).then((ok) => {
                          if (!ok) return;
                          setGcalBusy('disconnect');
                          void disconnectGcal()
                            .catch((e) => toast.error(errorMessage(e)))
                            .finally(() => setGcalBusy(''));
                        });
                      }}
                    >
                      <Unlink size={16} /> {t('gcal.disconnect')}
                    </Button>
                  </div>
                </>
              )}
            </CardBody>
          </Card>
        </Section>
      )}

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
