import { cn } from '@/lib/cn';
import wideSrc from '@/assets/logo-wide.png';
import markSrc from '@/assets/logo-mark.png';

interface LogoProps {
  /** `wide`: paw + "Yoshi Vet Care" wordmark. `mark`: paw only. */
  variant?: 'wide' | 'mark';
  className?: string;
}

/** Yoshi Vet Care logo. Size it with a height class (e.g. `h-8`); width follows. */
export function Logo({ variant = 'wide', className }: LogoProps) {
  return (
    <img
      src={variant === 'wide' ? wideSrc : markSrc}
      alt="Yoshi Vet Care"
      className={cn('block w-auto max-w-full select-none', className)}
      draggable={false}
    />
  );
}
