import {
  useEffect,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
  type ReactNode,
} from 'react';
import { toast } from 'sonner';
import { MoreVertical, Plus, Upload } from 'lucide-react';
import { type Clinic, type ClinicBrand, type ClinicMember, type ClinicMemberRole } from '@vetplus/shared';
import { useAuth } from '@/auth/AuthProvider';
import { useActiveClinic } from '@/app/ClinicProvider';
import {
  createClinicVet,
  deleteClinicLogoFile,
  sendStaffInvite,
  updateClinicBrand,
  updateClinicDetails,
  updateClinicMember,
  uploadClinicLogo,
} from '@/lib/clinicService';
import {
  VETTEMPO_BRAND,
  brandReadabilityWarning,
  brandVars,
  isHexColor,
} from '@/lib/brand';
import { EMAIL_RE } from '@/lib/contact';
import { inputBase } from '@/components/ui/TextField';
import { errorMessage } from '@/lib/format';
import { cn } from '@/lib/cn';
import { t } from '@/i18n';
import { PageHeader } from '@/components/ui/PageHeader';
import { Card, CardBody } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Dialog } from '@/components/ui/Dialog';
import { TextField } from '@/components/ui/TextField';
import { Select } from '@/components/ui/Select';
import { Menu } from '@/components/ui/Menu';
import { useConfirm } from '@/components/ui/Confirm';

type Member = ClinicMember & { uid: string };
type LogoKind = 'wide' | 'mark';

const MAX_LOGO_BYTES = 2 * 1024 * 1024;

/** Owner-only clinic settings: team, brand, clinic details. */
export function ClinicSettingsPage() {
  const { clinicId, clinic, members } = useActiveClinic();
  const { firebaseUser } = useAuth();
  const confirm = useConfirm();
  const uid = firebaseUser?.uid ?? '';
  const fail = (e: unknown) => toast.error(errorMessage(e, t('clinicSettings.saveFailed')));

  if (!clinicId) return null;
  return (
    <div className="mx-auto max-w-3xl">
      <PageHeader
        eyebrow={t('clinicSettings.eyebrow')}
        title={clinic?.name || t('nav.clinic')}
        subtitle={t('clinicSettings.subtitle')}
      />
      <TeamSection
        clinicId={clinicId}
        members={members}
        uid={uid}
        confirm={confirm}
        onError={fail}
      />
      {clinic && <BrandSection clinicId={clinicId} clinic={clinic} onError={fail} />}
      {clinic && <DetailsSection clinicId={clinicId} clinic={clinic} onError={fail} />}
    </div>
  );
}

/* --------------------------------- Equipa ---------------------------------- */

function TeamSection({
  clinicId,
  members,
  uid,
  confirm,
  onError,
}: {
  clinicId: string;
  members: Member[];
  uid: string;
  confirm: ReturnType<typeof useConfirm>;
  onError: (e: unknown) => void;
}) {
  const [addOpen, setAddOpen] = useState(false);
  const activeOwners = useMemo(
    () => members.filter((m) => m.role === 'owner' && m.active !== false),
    [members],
  );
  const isOnlyOwner = (m: Member) =>
    m.role === 'owner' && m.active !== false && activeOwners.length === 1;

  const run = (p: Promise<unknown>, ok?: string) =>
    p.then(() => ok && toast.success(ok)).catch(onError);

  const toggleRole = (m: Member) =>
    void run(
      updateClinicMember({
        clinicId,
        uid: m.uid,
        role: m.role === 'owner' ? 'vet' : 'owner',
      }),
      m.role === 'owner' ? t('clinicSettings.demoted', { name: m.displayName }) : t('clinicSettings.promoted', { name: m.displayName }),
    );

  const setActive = async (m: Member, active: boolean) => {
    if (active) {
      void run(
        updateClinicMember({ clinicId, uid: m.uid, active: true }),
        t('clinicSettings.reactivated', { name: m.displayName }),
      );
      return;
    }
    const ok = await confirm({
      title: t('clinicSettings.deactivateTitle'),
      description: t('clinicSettings.deactivateDesc', { name: m.displayName }),
      confirmLabel: t('clinicSettings.deactivate'),
      danger: true,
    });
    if (!ok) return;
    void run(
      updateClinicMember({ clinicId, uid: m.uid, active: false }),
      t('clinicSettings.deactivated', { name: m.displayName }),
    );
  };

  const resendInvite = (m: Member) =>
    void run(sendStaffInvite(m.email), t('clinicSettings.inviteSent', { email: m.email }));

  return (
    <Section
      title={t('clinicSettings.team')}
      action={
        <Button size="sm" onClick={() => setAddOpen(true)}>
          <Plus size={15} /> {t('clinicSettings.addVet')}
        </Button>
      }
    >
      <Card>
        <ul className="divide-y divide-border">
          {members.map((m) => {
            const locked = isOnlyOwner(m);
            return (
              <li
                key={m.uid}
                className={cn('flex items-center gap-3 p-4', m.active === false && 'opacity-60')}
              >
                <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-primary-light font-semibold text-primary">
                  {(m.displayName || m.email || '?').charAt(0).toUpperCase()}
                </span>
                <span className="min-w-0 flex-1">
                  <span className="flex items-center gap-2">
                    <span className="truncate font-medium text-foreground">
                      {m.displayName || m.email}
                    </span>
                    {m.uid === uid && (
                      <span className="shrink-0 text-xs text-muted-foreground">
                        ({t('clinicSettings.you')})
                      </span>
                    )}
                    <span className="shrink-0 rounded-full bg-secondary px-2 py-0.5 text-xs font-medium text-muted-foreground">
                      {m.role === 'owner' ? t('clinicSettings.owner') : t('clinicSettings.vet')}
                    </span>
                    {m.active === false && (
                      <span className="shrink-0 rounded-full bg-destructive/10 px-2 py-0.5 text-xs font-medium text-destructive">
                        {t('clinicSettings.inactive')}
                      </span>
                    )}
                  </span>
                  <span className="block truncate text-xs text-muted-foreground">{m.email}</span>
                </span>
                <Menu
                  label={t('clinicSettings.memberActions')}
                  trigger={<MoreVertical size={16} />}
                  items={[
                    ...(m.active !== false && !(locked && m.role === 'owner')
                      ? [
                          {
                            label:
                              m.role === 'owner'
                                ? t('clinicSettings.makeVet')
                                : t('clinicSettings.makeOwner'),
                            onClick: () => toggleRole(m),
                          },
                        ]
                      : []),
                    {
                      label: t('clinicSettings.resendInvite'),
                      onClick: () => resendInvite(m),
                    },
                    m.active === false
                      ? {
                          label: t('clinicSettings.reactivate'),
                          onClick: () => void setActive(m, true),
                        }
                      : {
                          label: t('clinicSettings.deactivate'),
                          danger: true,
                          onClick: () => void setActive(m, false),
                        },
                  ]}
                />
              </li>
            );
          })}
        </ul>
      </Card>
      <AddVetDialog open={addOpen} onClose={() => setAddOpen(false)} clinicId={clinicId} />
    </Section>
  );
}

function AddVetDialog({
  open,
  onClose,
  clinicId,
}: {
  open: boolean;
  onClose: () => void;
  clinicId: string;
}) {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [role, setRole] = useState<ClinicMemberRole>('vet');
  const [errors, setErrors] = useState<{ name?: string; email?: string }>({});
  const [saving, setSaving] = useState(false);
  const nameRef = useRef<HTMLInputElement>(null);
  const emailRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (open) {
      setName('');
      setEmail('');
      setRole('vet');
      setErrors({});
    }
  }, [open]);

  const submit = async () => {
    const next = {
      name: !name.trim() ? t('vet.clients.nameRequired') : undefined,
      email: !EMAIL_RE.test(email.trim()) ? t('clinicSettings.emailInvalid') : undefined,
    };
    setErrors(next);
    if (next.name || next.email) {
      (next.name ? nameRef : emailRef).current?.focus();
      return;
    }
    setSaving(true);
    try {
      const res = await createClinicVet({
        clinicId,
        name,
        email,
        role,
      });
      if (res.created) {
        try {
          await sendStaffInvite(email.trim().toLowerCase());
          toast.success(t('clinicSettings.inviteSent', { email: email.trim().toLowerCase() }));
        } catch {
          toast.success(t('clinicSettings.addedNoInvite', { name: name.trim() }));
        }
      } else {
        toast.success(t('clinicSettings.addedExisting', { name: name.trim() }));
      }
      onClose();
    } catch (e) {
      const msg = errorMessage(e, t('clinicSettings.saveFailed'));
      // Account-type errors (client email etc.) land on the email field.
      if (msg.toLowerCase().includes('email')) setErrors({ email: msg });
      else toast.error(msg);
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog
      open={open}
      onClose={() => (saving ? undefined : onClose())}
      title={t('clinicSettings.addVet')}
      footer={
        <>
          <Button variant="outline" disabled={saving} onClick={onClose}>
            {t('common.cancel')}
          </Button>
          <Button loading={saving} onClick={() => void submit()}>
            {t('common.add')}
          </Button>
        </>
      }
    >
      <form
        className="space-y-3"
        onSubmit={(e) => {
          e.preventDefault();
          void submit();
        }}
      >
        <TextField
          ref={nameRef}
          label={t('common.name')}
          value={name}
          error={errors.name}
          onChange={(e) => {
            setName(e.target.value);
            setErrors((x) => ({ ...x, name: undefined }));
          }}
        />
        <TextField
          ref={emailRef}
          label={t('common.email')}
          type="email"
          value={email}
          error={errors.email}
          onChange={(e) => {
            setEmail(e.target.value);
            setErrors((x) => ({ ...x, email: undefined }));
          }}
        />
        <Select
          label={t('clinicSettings.role')}
          value={role}
          onChange={(e) => setRole(e.target.value as ClinicMemberRole)}
        >
          <option value="vet">{t('clinicSettings.vet')}</option>
          <option value="owner">{t('clinicSettings.owner')}</option>
        </Select>
        <button type="submit" hidden />
      </form>
    </Dialog>
  );
}

/* ---------------------------------- Marca ---------------------------------- */

function BrandSection({
  clinicId,
  clinic,
  onError,
}: {
  clinicId: string;
  clinic: Clinic;
  onError: (e: unknown) => void;
}) {
  const [primary, setPrimary] = useState(clinic.brand.primary || VETTEMPO_BRAND.primary);
  const [accent, setAccent] = useState(clinic.brand.accent ?? '');
  const [logoWideUrl, setLogoWideUrl] = useState(clinic.brand.logoWideUrl ?? null);
  const [logoMarkUrl, setLogoMarkUrl] = useState(clinic.brand.logoMarkUrl ?? null);
  const [primaryError, setPrimaryError] = useState('');
  const [saving, setSaving] = useState(false);

  const draft: ClinicBrand = useMemo(
    () => ({
      primary: isHexColor(primary) ? primary : clinic.brand.primary || VETTEMPO_BRAND.primary,
      accent: isHexColor(accent) ? accent : null,
      logoWideUrl,
      logoMarkUrl,
    }),
    [primary, accent, logoWideUrl, logoMarkUrl, clinic.brand.primary],
  );

  const saved = clinic.brand;
  const dirty =
    draft.primary !== (saved.primary || '') ||
    (draft.accent ?? null) !== (saved.accent ?? null) ||
    (logoWideUrl ?? null) !== (saved.logoWideUrl ?? null) ||
    (logoMarkUrl ?? null) !== (saved.logoMarkUrl ?? null);

  const save = async () => {
    if (!isHexColor(primary)) {
      setPrimaryError(t('clinicSettings.hexInvalid'));
      return;
    }
    setSaving(true);
    const prevWide = saved.logoWideUrl ?? null;
    const prevMark = saved.logoMarkUrl ?? null;
    try {
      await updateClinicBrand(clinicId, { ...draft, primary });
      toast.success(t('clinicSettings.brandSaved'));
      // Best-effort cleanup of replaced logo files.
      if (prevWide && prevWide !== logoWideUrl) void deleteClinicLogoFile(clinicId, prevWide);
      if (prevMark && prevMark !== logoMarkUrl) void deleteClinicLogoFile(clinicId, prevMark);
    } catch (e) {
      onError(e);
    } finally {
      setSaving(false);
    }
  };

  return (
    <Section title={t('clinicSettings.brand')}>
      <Card>
        <CardBody className="space-y-5">
          <div className="grid gap-4 sm:grid-cols-2">
            <ColorField
              label={t('clinicSettings.primary')}
              value={primary}
              error={primaryError}
              onChange={(v) => {
                setPrimary(v);
                setPrimaryError('');
              }}
            />
            <ColorField
              label={t('clinicSettings.accent')}
              value={accent}
              hint={t('clinicSettings.accentHint')}
              onChange={setAccent}
            />
          </div>
          {isHexColor(primary) && brandReadabilityWarning(primary) && (
            <p className="rounded-(--radius-md) bg-warning/15 p-3 text-sm text-foreground">
              {t('clinicSettings.contrastWarn')}
            </p>
          )}
          {isHexColor(primary) && !primaryError && <BrandPreview brand={draft} clinicName={clinic.name} />}

          <div className="grid gap-4 sm:grid-cols-2">
            <LogoPicker
              kind="wide"
              label={t('clinicSettings.logoWide')}
              url={logoWideUrl}
              clinicId={clinicId}
              onChange={setLogoWideUrl}
              onError={onError}
            />
            <LogoPicker
              kind="mark"
              label={t('clinicSettings.logoMark')}
              url={logoMarkUrl}
              clinicId={clinicId}
              onChange={setLogoMarkUrl}
              onError={onError}
            />
          </div>

          <div className="flex flex-wrap items-center justify-between gap-3 border-t border-border pt-4">
            <button
              type="button"
              onClick={() => {
                setPrimary(VETTEMPO_BRAND.primary);
                setAccent(VETTEMPO_BRAND.accent ?? '');
              }}
              className="text-sm font-medium text-muted-foreground hover:text-foreground hover:underline"
            >
              {t('clinicSettings.resetColors')}
            </button>
            <Button loading={saving} disabled={!dirty} onClick={() => void save()}>
              {t('common.save')}
            </Button>
          </div>
        </CardBody>
      </Card>
    </Section>
  );
}

/** A color picker paired with a hex text field, kept in sync. */
function ColorField({
  label,
  value,
  onChange,
  error,
  hint,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  error?: string;
  hint?: string;
}) {
  return (
    <div>
      <span className="mb-1.5 block text-sm font-medium text-foreground">{label}</span>
      <div className="flex items-start gap-2">
        <input
          type="color"
          aria-label={label}
          value={isHexColor(value) ? value : '#0E7C72'}
          onChange={(e) => onChange(e.target.value.toUpperCase())}
          className="h-11 w-11 shrink-0 cursor-pointer rounded-(--radius-sm) border border-input bg-card p-1"
        />
        <div className="flex-1">
          <input
            aria-label={`${label} (hex)`}
            value={value}
            placeholder="#0E7C72"
            maxLength={7}
            aria-invalid={Boolean(error)}
            onChange={(e) => onChange(e.target.value)}
            className={cn(
              inputBase,
              error ? 'border-destructive' : 'border-input',
            )}
          />
          {error ? (
            <p aria-live="polite" className="mt-1.5 text-xs font-medium text-destructive">
              {error}
            </p>
          ) : hint ? (
            <p className="mt-1.5 text-xs text-muted-foreground">{hint}</p>
          ) : null}
        </div>
      </div>
    </div>
  );
}

/** Live mini preview rendered inside the draft brand's vars (not the app's). */
function BrandPreview({ brand, clinicName }: { brand: ClinicBrand; clinicName: string }) {
  const style = brandVars(brand) as CSSProperties;
  return (
    <div style={style} className="overflow-hidden rounded-(--radius-md) border border-border">
      <div className="flex items-center gap-3 border-b border-border bg-card px-4 py-3">
        <span className="truncate font-semibold text-foreground">{clinicName}</span>
        <span className="ml-auto rounded-full bg-primary-light px-2.5 py-1 text-xs font-semibold text-primary">
          3
        </span>
      </div>
      <div className="flex flex-wrap items-center gap-3 bg-card px-4 py-3">
        <span className="rounded-full bg-primary-light px-3 py-1.5 text-xs font-medium text-primary">
          {t('nav.agenda')}
        </span>
        <span className="text-sm text-muted-foreground">{t('nav.clients')}</span>
        <Button size="sm">{t('common.save')}</Button>
        <a
          href="#"
          onClick={(e) => e.preventDefault()}
          className="text-sm font-medium text-primary hover:underline"
        >
          {t('clinicSettings.previewLink')}
        </a>
      </div>
    </div>
  );
}

function LogoPicker({
  kind,
  label,
  url,
  clinicId,
  onChange,
  onError,
}: {
  kind: LogoKind;
  label: string;
  url: string | null;
  clinicId: string;
  onChange: (url: string | null) => void;
  onError: (e: unknown) => void;
}) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const pick = async (file: File) => {
    if (!file.type.startsWith('image/') || file.size >= MAX_LOGO_BYTES) {
      setError(t('clinicSettings.logoInvalid'));
      return;
    }
    setError('');
    setBusy(true);
    try {
      onChange(await uploadClinicLogo(clinicId, kind, file));
    } catch (e) {
      onError(e);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div>
      <span className="mb-1.5 block text-sm font-medium text-foreground">{label}</span>
      <div className="rounded-(--radius-md) border border-border bg-secondary/40 p-3">
        <div className="flex h-14 items-center justify-center">
          {url ? (
            <img src={url} alt={label} className="max-h-14 max-w-full object-contain" />
          ) : (
            <span className="text-xs text-muted-foreground">{t('clinicSettings.noLogo')}</span>
          )}
        </div>
        <div className="mt-2 flex items-center justify-center gap-2">
          <input
            ref={inputRef}
            type="file"
            accept="image/png,image/svg+xml,image/webp,image/jpeg"
            className="hidden"
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) void pick(f);
              e.target.value = '';
            }}
          />
          <Button
            variant="outline"
            size="sm"
            loading={busy}
            onClick={() => inputRef.current?.click()}
          >
            <Upload size={14} /> {url ? t('clinicSettings.replaceLogo') : t('clinicSettings.uploadLogo')}
          </Button>
          {url && (
            <Button variant="ghost" size="sm" onClick={() => onChange(null)}>
              {t('common.remove')}
            </Button>
          )}
        </div>
        {error && (
          <p aria-live="polite" className="mt-2 text-center text-xs font-medium text-destructive">
            {error}
          </p>
        )}
      </div>
    </div>
  );
}

/* ------------------------------ Dados da clínica ---------------------------- */

function DetailsSection({
  clinicId,
  clinic,
  onError,
}: {
  clinicId: string;
  clinic: Clinic;
  onError: (e: unknown) => void;
}) {
  const [name, setName] = useState(clinic.name);
  const [phone, setPhone] = useState(clinic.contact.phone ?? '');
  const [address, setAddress] = useState(clinic.contact.address ?? '');
  const [postalCode, setPostalCode] = useState(clinic.contact.postalCode ?? '');
  const [nameError, setNameError] = useState('');
  const [saving, setSaving] = useState(false);
  const nameRef = useRef<HTMLInputElement>(null);

  const dirty =
    name !== clinic.name ||
    phone !== (clinic.contact.phone ?? '') ||
    address !== (clinic.contact.address ?? '') ||
    postalCode !== (clinic.contact.postalCode ?? '');

  const save = async () => {
    if (!name.trim()) {
      setNameError(t('clinicSettings.nameRequired'));
      nameRef.current?.focus();
      return;
    }
    setSaving(true);
    try {
      await updateClinicDetails(clinicId, {
        name,
        contact: { phone, address, postalCode },
      });
      toast.success(t('clinicSettings.detailsSaved'));
    } catch (e) {
      onError(e);
    } finally {
      setSaving(false);
    }
  };

  return (
    <Section title={t('clinicSettings.details')}>
      <Card>
        <CardBody className="space-y-4">
          <TextField
            ref={nameRef}
            label={t('common.name')}
            value={name}
            error={nameError}
            onChange={(e) => {
              setName(e.target.value);
              setNameError('');
            }}
          />
          <div className="grid gap-4 sm:grid-cols-2">
            <TextField
              label={t('common.phone')}
              type="tel"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
            />
            <TextField
              label={t('clinicSettings.postalCode')}
              value={postalCode}
              onChange={(e) => setPostalCode(e.target.value)}
            />
          </div>
          <TextField
            label={t('clinicSettings.address')}
            value={address}
            onChange={(e) => setAddress(e.target.value)}
          />
          <div className="flex justify-end">
            <Button loading={saving} disabled={!dirty} onClick={() => void save()}>
              {t('common.save')}
            </Button>
          </div>
        </CardBody>
      </Card>
    </Section>
  );
}

function Section({
  title,
  action,
  children,
}: {
  title: string;
  action?: ReactNode;
  children: ReactNode;
}) {
  return (
    <section className="mb-8">
      <div className="mb-3 flex items-center justify-between gap-3">
        <h2 className="flex items-center gap-2 font-display text-xl font-bold text-foreground">
          {title}
        </h2>
        {action}
      </div>
      {children}
    </section>
  );
}
