import { useEffect, useState } from 'react';
import { Link, Navigate, useParams } from 'react-router-dom';
import { toast } from 'sonner';
import { Phone, PawPrint, Bell } from 'lucide-react';
import { useAuth } from '@/auth/AuthProvider';
import { getPetTag, sendFoundReport, type PetTag } from '@/lib/petTagService';
import { errorMessage } from '@/lib/format';
import { PetAvatar } from '@/components/ui/PetAvatar';
import { Button } from '@/components/ui/Button';
import { TextField } from '@/components/ui/TextField';
import { Textarea } from '@/components/ui/Textarea';
import { Logo } from '@/components/ui/Logo';
import { LangToggle } from '@/components/ui/AuthShell';
import { PageSpinner } from '@/components/Spinner';
import { t } from '@/i18n';

/**
 * Public pet-tag page at /t/:petId. Signed-in owner → their pet page, their
 * vet → the client pet page, everyone else → the safe public card + a
 * "alert the owner" form.
 */
export function PetTagPage() {
  const { petId = '' } = useParams<{ petId: string }>();
  const { firebaseUser, role, loading } = useAuth();
  const [tag, setTag] = useState<PetTag | null | undefined>(undefined);

  useEffect(() => {
    let on = true;
    getPetTag(petId)
      .then((v) => on && setTag(v))
      .catch(() => on && setTag(null));
    return () => {
      on = false;
    };
  }, [petId]);

  if (loading || tag === undefined) return <PageSpinner />;

  if (firebaseUser && tag) {
    if (firebaseUser.uid === tag.ownerId) return <Navigate to={`/pets/${petId}`} replace />;
    if (role === 'vet') {
      return <Navigate to={`/clients/${tag.ownerId}/pets/${petId}`} replace />;
    }
  }

  const firstName = tag?.contactName?.trim().split(' ')[0] ?? '';

  return (
    <div className="relative flex min-h-dvh flex-col items-center justify-center px-5 py-12">
      <LangToggle />
      <div
        aria-hidden
        className="pointer-events-none absolute inset-x-0 top-0 h-72 bg-gradient-to-b from-primary-light to-transparent"
      />
      <div className="relative flex w-full max-w-md flex-col items-center">
        <Logo />
        <span className="mt-5 text-[0.8125rem] font-semibold uppercase tracking-[0.08em] text-primary">
          Yoshi Vet Care
        </span>

        <div className="mt-8 w-full rounded-(--radius-lg) border border-border bg-card p-6 text-center shadow-(--shadow-md) sm:p-7">
          {!tag ? (
            <>
              <PawPrint size={36} className="mx-auto text-muted-foreground" />
              <h1 className="mt-3 font-display text-xl font-bold text-foreground">
                {t('tag.inactive.title')}
              </h1>
              <p className="mt-1 text-sm text-muted-foreground">{t('tag.inactive.body')}</p>
            </>
          ) : (
            <>
              <PetAvatar pet={{ name: tag.petName, photoUrl: tag.photoUrl }} size={104} className="mx-auto" />
              <h1 className="mt-4 break-words font-display text-2xl font-bold text-foreground">
                {t('tag.hello', { name: tag.petName })}
              </h1>
              {(tag.species || tag.breed) && (
                <p className="mt-1 text-sm text-muted-foreground">
                  {[tag.species, tag.breed].filter(Boolean).join(' · ')}
                </p>
              )}
              {tag.microchip && (
                <p className="mt-1 text-sm text-muted-foreground">
                  {t('tag.microchip', { chip: tag.microchip })}
                </p>
              )}
              <p className="mt-4 text-sm text-muted-foreground">{t('tag.found')}</p>
              {tag.showContact && tag.contactName && (
                <p className="mt-3 font-medium text-foreground">
                  {t('tag.owner', { name: firstName })}
                </p>
              )}
              {tag.showContact && tag.contactPhone && (
                <Button className="mt-3" onClick={() => (window.location.href = `tel:${tag.contactPhone}`)}>
                  <Phone size={16} /> {t('tag.call', { phone: tag.contactPhone })}
                </Button>
              )}

              <FoundForm tag={tag} />
            </>
          )}
        </div>

        <p className="mt-6 text-center text-sm">
          <Link to="/" className="text-muted-foreground underline hover:text-foreground">
            {t('tag.signIn')}
          </Link>
        </p>
      </div>
    </div>
  );
}

/** "Found this pet?" collapsible alert form — anonymous, writes a foundReport
 *  the owner sees on their dashboard. */
function FoundForm({ tag }: { tag: PetTag }) {
  const [open, setOpen] = useState(false);
  const [name, setName] = useState('');
  const [contact, setContact] = useState('');
  const [message, setMessage] = useState('');
  const [contactError, setContactError] = useState('');
  const [sending, setSending] = useState(false);
  const [sent, setSent] = useState(false);

  const submit = async () => {
    if (contact.trim().length < 3) {
      setContactError(t('tag.contactRequired'));
      return;
    }
    setSending(true);
    try {
      await sendFoundReport(tag, { finderName: name, finderContact: contact, message });
      setSent(true);
    } catch (e) {
      toast.error(errorMessage(e));
    } finally {
      setSending(false);
    }
  };

  return (
    <div className="mt-6 border-t border-border pt-5 text-left">
      <h2 className="text-center text-sm font-semibold text-foreground">{t('tag.foundHeading')}</h2>
      {sent ? (
        <p className="mt-3 text-center text-sm text-muted-foreground">{t('tag.sent')}</p>
      ) : !open ? (
        <Button variant="outline" className="mt-3 w-full" onClick={() => setOpen(true)}>
          <Bell size={16} /> {t('tag.alert')}
        </Button>
      ) : (
        <div className="mt-3 space-y-3">
          <TextField label={t('tag.finderName')} value={name} onChange={(e) => setName(e.target.value)} />
          <TextField
            label={t('tag.finderContact')}
            value={contact}
            error={contactError}
            onChange={(e) => {
              setContact(e.target.value);
              setContactError('');
            }}
          />
          <Textarea
            label={t('tag.message')}
            placeholder={t('tag.messagePlaceholder')}
            value={message}
            onChange={(e) => setMessage(e.target.value)}
          />
          <Button className="w-full" loading={sending} onClick={() => void submit()}>
            {t('tag.sendAlert')}
          </Button>
        </div>
      )}
    </div>
  );
}
