import { useEffect, useState } from 'react';
import { Link, Navigate, useParams } from 'react-router-dom';
import { Phone, PawPrint } from 'lucide-react';
import { useAuth } from '@/auth/AuthProvider';
import { getPetTag, type PetTag } from '@/lib/petTagService';
import { PetAvatar } from '@/components/ui/PetAvatar';
import { Button } from '@/components/ui/Button';
import { Logo } from '@/components/ui/Logo';
import { LangToggle } from '@/components/ui/AuthShell';
import { PageSpinner } from '@/components/Spinner';
import { t } from '@/i18n';

/**
 * Public pet-tag page at /t/:petId. Signed-in owner → their pet page, their
 * vet → the client pet page, everyone else → the safe public card.
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

  const firstName = tag ? (tag.contactName.trim().split(' ')[0] ?? '') : '';

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
              <p className="mt-4 text-sm text-muted-foreground">{t('tag.found')}</p>
              <p className="mt-3 font-medium text-foreground">
                {t('tag.owner', { name: firstName })}
              </p>
              {tag.contactPhone ? (
                <Button className="mt-3" onClick={() => (window.location.href = `tel:${tag.contactPhone}`)}>
                  <Phone size={16} /> {t('tag.call', { phone: tag.contactPhone })}
                </Button>
              ) : (
                <p className="mt-3 text-sm text-muted-foreground">{t('tag.noContact')}</p>
              )}
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
