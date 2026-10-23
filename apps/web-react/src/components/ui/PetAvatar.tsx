import { PawPrint } from 'lucide-react';
import { cn } from '@/lib/cn';

interface PetAvatarProps {
  pet: { name: string; photoUrl: string | null };
  size?: number;
  className?: string;
}

/** Round pet avatar: photo, else the first letter on a brand tint, else a paw. */
export function PetAvatar({ pet, size = 48, className }: PetAvatarProps) {
  const name = pet.name.trim();
  return (
    <span
      className={cn(
        'inline-flex shrink-0 items-center justify-center overflow-hidden rounded-full bg-primary-light',
        className,
      )}
      style={{ width: size, height: size }}
    >
      {pet.photoUrl ? (
        <img src={pet.photoUrl} alt={pet.name} className="h-full w-full object-cover" />
      ) : name ? (
        <span
          className="font-display font-semibold leading-none text-primary/70"
          style={{ fontSize: Math.round(size * 0.42) }}
        >
          {name.charAt(0).toUpperCase()}
        </span>
      ) : (
        <PawPrint size={Math.round(size * 0.5)} className="text-primary/70" />
      )}
    </span>
  );
}
