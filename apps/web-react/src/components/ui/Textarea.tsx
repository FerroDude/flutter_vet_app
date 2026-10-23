import { forwardRef, useId, type TextareaHTMLAttributes } from 'react';
import { cn } from '@/lib/cn';

interface TextareaProps extends TextareaHTMLAttributes<HTMLTextAreaElement> {
  label: string;
  error?: string;
}

export const Textarea = forwardRef<HTMLTextAreaElement, TextareaProps>(
  function Textarea({ label, error, id, className, rows = 3, ...rest }, ref) {
    const autoId = useId();
    const fieldId = id ?? autoId;
    return (
      <div className="flex flex-col gap-1.5">
        <label htmlFor={fieldId} className="text-sm font-medium text-foreground">
          {label}
        </label>
        <textarea
          id={fieldId}
          ref={ref}
          rows={rows}
          aria-invalid={Boolean(error)}
          aria-describedby={error ? `${fieldId}-err` : undefined}
          className={cn(
            'w-full rounded-(--radius-md) border bg-card px-3.5 py-2.5 text-sm text-foreground',
            'placeholder:text-muted-foreground/70 transition-colors resize-y',
            'focus-visible:border-ring focus-visible:outline-1 focus-visible:outline-offset-0 focus-visible:outline-ring',
            error ? 'border-destructive' : 'border-input',
            className,
          )}
          {...rest}
        />
        {error && (
          <p id={`${fieldId}-err`} aria-live="polite" className="text-xs font-medium text-destructive">
            {error}
          </p>
        )}
      </div>
    );
  },
);
