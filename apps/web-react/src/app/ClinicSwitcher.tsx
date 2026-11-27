import { ChevronDown } from 'lucide-react';
import { useActiveClinic } from './ClinicProvider';
import { ClinicLogo } from '@/components/ui/Logo';
import { t } from '@/i18n';

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
  const { clinicId, clinicIds, clinics, setClinicId, clinic } = useActiveClinic();
  const multi = clinicIds.length >= 2;

  if (variant === 'header') {
    const label = (id: string) => {
      const name = clinics.find((c) => c.id === id)?.name ?? id;
      const n = id === clinicId ? 0 : (unreadByClinic?.[id] ?? 0);
      return n > 0 ? `${name} (${n})` : name;
    };
    return (
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
    );
  }

  if (!multi) return null;
  return (
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
  );
}
