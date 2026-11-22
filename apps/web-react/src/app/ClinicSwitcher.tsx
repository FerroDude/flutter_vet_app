import { useActiveClinic } from './ClinicProvider';
import { t } from '@/i18n';

/**
 * Dropdown to change the active clinic. Rendered under the sidebar logo
 * (desktop) and in Profile settings. Hidden with a single clinic.
 */
export function ClinicSwitcher() {
  const { clinicId, clinicIds, clinics, setClinicId } = useActiveClinic();
  if (clinicIds.length < 2) return null;
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
