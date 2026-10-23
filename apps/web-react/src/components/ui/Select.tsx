import { forwardRef, useId, type SelectHTMLAttributes } from 'react';
import { cn } from '@/lib/cn';

interface SelectProps extends SelectHTMLAttributes<HTMLSelectElement> {
  label: string;
  error?: string;
}

export const Select = forwardRef<HTMLSelectElement, SelectProps>(function Select(
  { label, error, id, className, children, ...rest },
  ref,
) {
  const autoId = useId();
  const fieldId = id ?? autoId;
  return (
    <div className="flex flex-col gap-1.5">
      <label htmlFor={fieldId} className="text-sm font-medium text-foreground">
        {label}
      </label>
      <select
        id={fieldId}
        ref={ref}
        aria-invalid={Boolean(error)}
        aria-describedby={error ? `${fieldId}-err` : undefined}
        className={cn(
          'h-11 w-full appearance-none rounded-(--radius-md) border bg-card px-3.5 text-sm text-foreground',
          'bg-[length:1rem] bg-[right_0.75rem_center] bg-no-repeat pr-10',
          'focus-visible:border-ring focus-visible:outline-1 focus-visible:outline-offset-0 focus-visible:outline-ring',
          error ? 'border-destructive' : 'border-input',
          className,
        )}
        style={{
          backgroundImage:
            "url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='%236b5a50' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='6 9 12 15 18 9'/%3E%3C/svg%3E\")",
        }}
        {...rest}
      >
        {children}
      </select>
      {error && (
        <p id={`${fieldId}-err`} aria-live="polite" className="text-xs font-medium text-destructive">
          {error}
        </p>
      )}
    </div>
  );
});
