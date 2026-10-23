import { cn } from '@/lib/cn';

interface LogoProps {
  size?: number;
  className?: string;
}

/** Yoshi Vet Care paw mark on a brand-orange tile. */
export function Logo({ size = 56, className }: LogoProps) {
  return (
    <span
      className={cn(
        'inline-grid place-items-center rounded-(--radius-lg) bg-primary text-primary-foreground shadow-(--shadow-md)',
        className,
      )}
      style={{ width: size, height: size }}
      aria-hidden
    >
      <svg width={size * 0.55} height={size * 0.55} viewBox="0 0 24 24" fill="currentColor">
        <circle cx="6" cy="10" r="2.1" />
        <circle cx="10.5" cy="6.5" r="2.1" />
        <circle cx="15" cy="6.5" r="2.1" />
        <circle cx="18.5" cy="10" r="2.1" />
        <path d="M12 12c-2.6 0-4.8 1.7-5.6 3.9-.6 1.6.6 3.1 2.3 3.1.9 0 1.7-.3 2.4-.6.6-.3 1.2-.3 1.8 0 .7.3 1.5.6 2.4.6 1.7 0 2.9-1.5 2.3-3.1C16.8 13.7 14.6 12 12 12Z" />
      </svg>
    </span>
  );
}
