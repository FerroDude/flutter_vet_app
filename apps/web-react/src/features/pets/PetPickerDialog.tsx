import { PawPrint } from 'lucide-react';
import { type Pet } from '@/lib/petService';
import { Dialog } from '@/components/ui/Dialog';

interface Props {
  open: boolean;
  onClose: () => void;
  pets: Pet[];
  title?: string;
  onPick: (pet: Pet) => void;
}

/** Pet selection step shared by the calendar add flows (mirrors the Flutter
 *  _showPetSelectionDialog). */
export function PetPickerDialog({ open, onClose, pets, title = 'Select a pet', onPick }: Props) {
  return (
    <Dialog open={open} onClose={onClose} title={title}>
      {pets.length === 0 ? (
        <p className="text-sm text-muted-foreground">Add a pet first.</p>
      ) : (
        <div className="flex flex-col gap-2">
          {pets.map((pet) => (
            <button
              key={pet.id}
              type="button"
              onClick={() => onPick(pet)}
              className="flex items-center gap-3 rounded-(--radius-md) border border-border p-3 text-left transition-colors hover:bg-secondary"
            >
              <span className="flex h-10 w-10 items-center justify-center overflow-hidden rounded-full bg-primary-light text-primary">
                {pet.photoUrl ? (
                  <img src={pet.photoUrl} alt={pet.name} className="h-full w-full object-cover" />
                ) : (
                  <PawPrint size={18} />
                )}
              </span>
              <span className="min-w-0">
                <span className="block truncate font-medium text-foreground">{pet.name}</span>
                <span className="block truncate text-xs text-muted-foreground">
                  {[pet.species, pet.breed].filter(Boolean).join(' · ') || 'Pet'}
                </span>
              </span>
            </button>
          ))}
        </div>
      )}
    </Dialog>
  );
}
