import { forwardRef, type ButtonHTMLAttributes } from 'react';
import { cn } from '@/lib/cn';
import { Spinner } from '@/components/Spinner';

type Variant = 'primary' | 'outline' | 'ghost' | 'destructive';
type Size = 'md' | 'lg';

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  size?: Size;
  loading?: boolean;
  fullWidth?: boolean;
}

const base =
  'inline-flex items-center justify-center gap-2 rounded-(--radius-pill) font-medium ' +
  'transition-[transform,background-color,box-shadow] duration-150 ease-(--ease-out) ' +
  'active:scale-[0.98] disabled:pointer-events-none disabled:opacity-60 ' +
  'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring';

const variants: Record<Variant, string> = {
  primary:
    'bg-primary text-primary-foreground shadow-(--shadow-sm) hover:bg-primary/90 hover:shadow-(--shadow-md)',
  outline:
    'border border-border bg-card text-foreground hover:bg-secondary',
  ghost: 'text-primary hover:bg-primary-light',
  destructive:
    'bg-destructive text-destructive-foreground hover:bg-destructive/90',
};

const sizes: Record<Size, string> = {
  md: 'h-11 px-5 text-sm',
  lg: 'h-12 px-6 text-base',
};

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { variant = 'primary', size = 'md', loading, fullWidth, className, children, disabled, ...rest },
  ref,
) {
  return (
    <button
      ref={ref}
      disabled={disabled || loading}
      aria-busy={loading || undefined}
      className={cn(
        base,
        variants[variant],
        sizes[size],
        fullWidth && 'w-full',
        className,
      )}
      {...rest}
    >
      {loading && <Spinner size={18} />}
      {children}
    </button>
  );
});
