import { type Pet } from '@/lib/petService';
import { Dialog } from '@/components/ui/Dialog';
import { PetAvatar } from '@/components/ui/PetAvatar';
import { t } from '@/i18n';

interface Props {
  open: boolean;
  onClose: () => void;
  pets: Pet[];
  title?: string;
  onPick: (pet: Pet) => void;
}

/** Pet selection step shared by the calendar add flows (mirrors the Flutter
 *  _showPetSelectionDialog). */
export function PetPickerDialog({ open, onClose, pets, title = t('pets.pick.title'), onPick }: Props) {
  return (
    <Dialog open={open} onClose={onClose} title={title}>
      {pets.length === 0 ? (
        <p className="text-sm text-muted-foreground">{t('agenda.addPetFirst')}</p>
      ) : (
        <div className="flex flex-col gap-2">
          {pets.map((pet) => (
            <button
              key={pet.id}
              type="button"
              onClick={() => onPick(pet)}
              className="flex items-center gap-3 rounded-(--radius-md) border border-border p-3 text-left transition-colors hover:bg-secondary"
            >
              <PetAvatar pet={pet} size={40} />
              <span className="min-w-0">
                <span className="block truncate font-medium text-foreground">{pet.name}</span>
                <span className="block truncate text-xs text-muted-foreground">
                  {[pet.species, pet.breed].filter(Boolean).join(' · ') || t('pets.unknown')}
                </span>
              </span>
            </button>
          ))}
        </div>
      )}
    </Dialog>
  );
}
