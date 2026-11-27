import * as Popover from '@radix-ui/react-popover';
import { ChevronDown } from 'lucide-react';
import { useActiveClinic } from './ClinicProvider';
import { ClinicLogo } from '@/components/ui/Logo';
import { Button } from '@/components/ui/Button';
import { useMediaQuery } from '@/lib/useMediaQuery';
import { t } from '@/i18n';

/** Anchored "new clinic added" hint on the switcher; dismissable, touch-safe. */
function ClinicHint({ open, children }: { open: boolean; children: React.ReactNode }) {
  const { newClinicHint, clinics, setClinicId, dismissClinicHint } = useActiveClinic();
  const name = clinics.find((c) => c.id === newClinicHint)?.name ?? '';
  return (
    <Popover.Root
      open={open}
      onOpenChange={(o) => {
        if (!o) dismissClinicHint();
      }}
    >
      <Popover.Anchor asChild>{children}</Popover.Anchor>
      <Popover.Portal>
        <Popover.Content
          side="bottom"
          align="start"
          collisionPadding={12}
          className="z-50 w-64 rounded-(--radius-md) border border-border bg-card p-3 shadow-(--shadow-md)"
        >
          <Popover.Arrow className="fill-border" />
          <p className="text-sm text-foreground">{t('clinicLink.hint', { name })}</p>
          <div className="mt-2.5 flex justify-end gap-2">
            <Button variant="ghost" size="sm" onClick={dismissClinicHint}>
              {t('common.ok')}
            </Button>
            <Button
              size="sm"
              onClick={() => {
                if (newClinicHint) setClinicId(newClinicHint);
                dismissClinicHint();
              }}
            >
              {t('clinicLink.switchNow')}
            </Button>
          </div>
        </Popover.Content>
      </Popover.Portal>
    </Popover.Root>
  );
}

/**
 * Clinic switcher. `sidebar` is the small select rendered under the sidebar
 * logo (desktop) and in Profile settings. `header` is the mobile top-bar
 * variant: the clinic logo + a chevron with an invisible native <select>
 * overlaid so tapping the logo opens the OS picker.
 * With fewer than 2 clinics the header variant still shows the plain logo
 * (so the mobile bar keeps its identity); sidebar renders nothing.
 */
export function ClinicSwitcher({
  variant = 'sidebar',
  unreadByClinic,
}: {
  variant?: 'sidebar' | 'header';
  /** Optional "name (n)" unread labels per clinic (client only). */
  unreadByClinic?: Record<string, number>;
}) {
  const { clinicId, clinicIds, clinics, setClinicId, clinic, newClinicHint } =
    useActiveClinic();
  const multi = clinicIds.length >= 2;
  // The hint only opens on the variant actually on screen (lg = sidebar).
  const onDesktop = useMediaQuery('(min-width: 1024px)');
  const hintHere =
    newClinicHint !== null &&
    newClinicHint !== clinicId &&
    clinicIds.includes(newClinicHint) &&
    clinics.some((c) => c.id === newClinicHint) &&
    (variant === 'header' ? !onDesktop : onDesktop);

  if (variant === 'header') {
    const label = (id: string) => {
      const name = clinics.find((c) => c.id === id)?.name ?? id;
      const n = id === clinicId ? 0 : (unreadByClinic?.[id] ?? 0);
      return n > 0 ? `${name} (${n})` : name;
    };
    return (
      <ClinicHint open={hintHere}>
        <div className="relative flex min-w-0 items-center gap-1">
          <ClinicLogo
            src={clinic?.brand?.logoWideUrl}
            name={clinic?.name ?? 'VetTempo'}
            className="h-auto max-h-9 min-w-0 max-w-[55vw] object-contain object-left"
          />
          {multi && <ChevronDown size={16} className="shrink-0 text-muted-foreground" aria-hidden />}
          {multi && (
            <select
              value={clinicId}
              onChange={(e) => setClinicId(e.target.value)}
              aria-label={t('clinic.switch')}
              className="absolute inset-0 h-full w-full cursor-pointer opacity-0"
            >
              {clinicIds.map((id) => (
                <option key={id} value={id}>
                  {label(id)}
                </option>
              ))}
            </select>
          )}
        </div>
      </ClinicHint>
    );
  }

  if (!multi) return null;
  return (
    <ClinicHint open={hintHere}>
      <select
        value={clinicId}
        onChange={(e) => setClinicId(e.target.value)}
        aria-label={t('clinic.switch')}
        className="mt-2 h-8 w-full rounded-(--radius-md) border border-input bg-card px-2 text-xs text-foreground focus-visible:border-ring focus-visible:outline-1 focus-visible:outline-offset-0 focus-visible:outline-ring"
      >
        {clinicIds.map((id) => (
          <option key={id} value={id}>
            {clinics.find((c) => c.id === id)?.name ?? id}
          </option>
        ))}
      </select>
    </ClinicHint>
  );
}
