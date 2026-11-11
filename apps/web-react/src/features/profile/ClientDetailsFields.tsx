import { type UserProfile } from '@vetplus/shared';
import { type ClientDetails } from '@/lib/clientService';
import { t } from '@/i18n';
import { TextField } from '@/components/ui/TextField';

export type ClientDetailsDraft = Record<keyof ClientDetails, string>;

export const draftFromProfile = (p: UserProfile | null | undefined): ClientDetailsDraft => ({
  phone: p?.phone ?? '',
  phone2: p?.phone2 ?? '',
  address: p?.address ?? '',
  postalCode: p?.postalCode ?? '',
  country: p?.country ?? '',
  nif: p?.nif ?? '',
});

export const detailsFromDraft = (d: ClientDetailsDraft): ClientDetails => ({
  phone: d.phone.trim() || null,
  phone2: d.phone2.trim() || null,
  address: d.address.trim() || null,
  postalCode: d.postalCode.trim() || null,
  country: d.country.trim() || null,
  nif: d.nif.trim() || null,
});

/** The 6 optional client contact fields — shared by the client's own Perfil
 *  and the vet's "Editar dados" dialog. */
export function ClientDetailsFields({
  draft,
  onChange,
}: {
  draft: ClientDetailsDraft;
  onChange: (next: ClientDetailsDraft) => void;
}) {
  const set = (k: keyof ClientDetailsDraft) => (e: React.ChangeEvent<HTMLInputElement>) =>
    onChange({ ...draft, [k]: e.target.value });

  return (
    <div className="space-y-4">
      <div className="grid gap-4 sm:grid-cols-2">
        <TextField label={t('profile.mobile')} type="tel" autoComplete="tel" value={draft.phone} onChange={set('phone')} />
        <TextField label={t('profile.phone2')} type="tel" autoComplete="tel" value={draft.phone2} onChange={set('phone2')} />
      </div>
      <div className="grid gap-4 sm:grid-cols-[minmax(0,1fr)_10rem]">
        <TextField
          label={t('profile.address')}
          autoComplete="street-address"
          value={draft.address}
          onChange={set('address')}
        />
        <TextField
          label={t('profile.postalCode')}
          placeholder="1000-001"
          maxLength={12}
          autoComplete="postal-code"
          value={draft.postalCode}
          onChange={set('postalCode')}
        />
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        <TextField
          label={t('profile.country')}
          placeholder="Portugal"
          autoComplete="country-name"
          value={draft.country}
          onChange={set('country')}
        />
        <TextField
          label={t('profile.nif')}
          maxLength={20}
          autoComplete="off"
          value={draft.nif}
          onChange={set('nif')}
        />
      </div>
    </div>
  );
}
