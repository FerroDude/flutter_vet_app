import * as DropdownMenu from '@radix-ui/react-dropdown-menu';
import * as Popover from '@radix-ui/react-popover';
import { Check, ChevronsUpDown } from 'lucide-react';
import type { Clinic } from '@vetplus/shared';
import { useActiveClinic } from './ClinicProvider';
import { ClinicLogo, ClinicMark } from '@/components/ui/Logo';
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
          className="z-50 w-64 rounded-(--radius-lg) border border-border bg-card p-3 shadow-(--shadow-md)"
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
 * Workspace-style clinic switcher. `sidebar` is the big identity block at the
 * top of the sidebar (logo + ChevronsUpDown, whole block is the trigger);
 * `header` is the compact mobile top-bar trigger. Both open the same Radix
 * DropdownMenu; with one clinic the block is a plain non-interactive logo.
 */
export function ClinicSwitcher({
  variant = 'sidebar',
  unreadByClinic,
  menuOpen,
}: {
  variant?: 'sidebar' | 'header';
  /** Optional unread pills on the menu items (client only). */
  unreadByClinic?: Record<string, number>;
  /** Controlled-open override (screenshot/test harness). */
  menuOpen?: boolean;
}) {
  const {
    clinicId,
    clinicIds,
    clinics,
    setClinicId,
    clinic,
    newClinicHint,
    dismissClinicHint,
  } = useActiveClinic();
  const multi = clinicIds.length >= 2;
  // The hint only opens on the variant actually on screen (lg = sidebar).
  const onDesktop = useMediaQuery('(min-width: 1024px)');
  // Only for a clinic that is actually listed and not active (a stale hint from
  // another account on this device, or a link still landing, stays closed).
  const hintHere =
    newClinicHint !== null &&
    newClinicHint !== clinicId &&
    clinicIds.includes(newClinicHint) &&
    clinics.some((c) => c.id === newClinicHint) &&
    (variant === 'header' ? !onDesktop : onDesktop);

  const logoClass =
    variant === 'header'
      ? 'h-auto max-h-9 min-w-0 max-w-[55vw] object-contain object-left'
      : 'h-auto max-h-14 min-w-0 max-w-full object-contain object-left';
  const logo = <ClinicLogo src={clinic?.brand?.logoWideUrl} name={clinic?.name ?? 'VetTempo'} className={logoClass} />;

  const list: Clinic[] = clinicIds.map(
    (id) => clinics.find((c) => c.id === id) ?? ({ id, name: id } as Clinic),
  );

  const block = multi ? (
    <DropdownMenu.Root open={menuOpen}>
      <DropdownMenu.Trigger asChild>
        <button
          type="button"
          aria-label={`${t('clinic.switch')} — ${clinic?.name ?? ''}`}
          onClick={() => hintHere && dismissClinicHint()}
          className="flex min-h-11 w-full min-w-0 items-center gap-2 rounded-(--radius-md) px-2 py-1.5 text-left transition-colors hover:bg-secondary focus-visible:outline-1 focus-visible:outline-ring"
        >
          <span className="min-w-0 flex-1">{logo}</span>
          <ChevronsUpDown size={16} className="shrink-0 text-muted-foreground" aria-hidden />
        </button>
      </DropdownMenu.Trigger>
      <DropdownMenu.Portal>
        <DropdownMenu.Content
          side="bottom"
          align="start"
          sideOffset={6}
          collisionPadding={12}
          className="z-50 w-[280px] max-w-[calc(100vw-24px)] rounded-(--radius-lg) border border-border bg-card p-1 shadow-(--shadow-md) data-[state=open]:animate-menu-in data-[state=closed]:animate-menu-out"
        >
          <DropdownMenu.Label className="px-2 pb-1 pt-1.5 text-xs text-muted-foreground">
            {t('clinic.switchLabel')}
          </DropdownMenu.Label>
          <DropdownMenu.RadioGroup value={clinicId} onValueChange={setClinicId}>
            {list.map((c) => {
              const unread = c.id === clinicId ? 0 : (unreadByClinic?.[c.id] ?? 0);
              const isNew = c.id === newClinicHint;
              return (
                <DropdownMenu.RadioItem
                  key={c.id}
                  value={c.id}
                  className="flex min-h-11 cursor-pointer items-center gap-3 rounded-(--radius-md) px-2 text-sm font-medium text-foreground outline-none data-[highlighted]:bg-secondary"
                >
                  <ClinicMark brand={c.brand} name={c.name} size={28} />
                  <span className="min-w-0 flex-1 truncate">{c.name}</span>
                  {c.id === clinicId ? (
                    <Check size={16} className="shrink-0 text-primary" aria-hidden />
                  ) : isNew ? (
                    <span className="shrink-0 rounded-full bg-primary-light px-2 py-0.5 text-xs font-medium text-primary">
                      {t('clinic.new')}
                    </span>
                  ) : unread > 0 ? (
                    <span
                      aria-label={t('clinic.unreadCount', { count: unread })}
                      className="grid h-5 min-w-5 shrink-0 place-items-center rounded-full bg-primary px-1.5 text-xs font-semibold tabular-nums text-primary-foreground"
                    >
                      {unread}
                    </span>
                  ) : null}
                </DropdownMenu.RadioItem>
              );
            })}
          </DropdownMenu.RadioGroup>
        </DropdownMenu.Content>
      </DropdownMenu.Portal>
    </DropdownMenu.Root>
  ) : (
    <div className="px-2 py-1.5">{logo}</div>
  );

  return <ClinicHint open={hintHere}>{block}</ClinicHint>;
}
