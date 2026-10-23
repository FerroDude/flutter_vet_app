import { useEffect, useId, useRef, type ReactNode } from 'react';
import { cn } from '@/lib/cn';

interface DialogProps {
  open: boolean;
  onClose: () => void;
  title: string;
  description?: string;
  children?: ReactNode;
  footer?: ReactNode;
  className?: string;
}

const FOCUSABLE =
  'a[href],button:not([disabled]),textarea:not([disabled]),input:not([disabled]),select:not([disabled]),[tabindex]:not([tabindex="-1"])';

/**
 * Accessible modal: Escape to close, click backdrop to dismiss, focus is moved
 * into the dialog on open and trapped inside (Tab cycles within), and restored
 * to the triggering element on close. role="dialog" + aria-modal + labelled by
 * the title and described by the description.
 */
export function Dialog({
  open,
  onClose,
  title,
  description,
  children,
  footer,
  className,
}: DialogProps) {
  const panelRef = useRef<HTMLDivElement>(null);
  const onCloseRef = useRef(onClose);
  onCloseRef.current = onClose;

  const titleId = useId();
  const descId = useId();

  useEffect(() => {
    if (!open) return;
    const previouslyFocused = document.activeElement as HTMLElement | null;

    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault();
        onCloseRef.current();
        return;
      }
      if (e.key !== 'Tab') return;
      const panel = panelRef.current;
      if (!panel) return;
      const items = Array.from(panel.querySelectorAll<HTMLElement>(FOCUSABLE)).filter(
        (el) => el.offsetParent !== null || el === document.activeElement,
      );
      if (items.length === 0) {
        e.preventDefault();
        panel.focus();
        return;
      }
      const first = items[0]!;
      const last = items[items.length - 1]!;
      const active = document.activeElement;
      if (e.shiftKey && (active === first || active === panel)) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && active === last) {
        e.preventDefault();
        first.focus();
      }
    };

    document.addEventListener('keydown', onKey);
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';

    const raf = requestAnimationFrame(() => {
      const focusables = panelRef.current?.querySelectorAll<HTMLElement>(FOCUSABLE);
      (focusables && focusables.length > 0 ? focusables[0] : panelRef.current)?.focus();
    });

    return () => {
      document.removeEventListener('keydown', onKey);
      document.body.style.overflow = prevOverflow;
      cancelAnimationFrame(raf);
      // Restore focus to whatever opened the dialog.
      previouslyFocused?.focus?.();
    };
  }, [open]);

  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      {/* Clicks on the backdrop land here (it covers the wrapper), so it closes too. */}
      <div
        className="absolute inset-0 bg-foreground/40 backdrop-blur-[2px] animate-overlay-in"
        aria-hidden
        onMouseDown={onClose}
      />
      <div
        ref={panelRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        aria-describedby={description ? descId : undefined}
        tabIndex={-1}
        className={cn(
          'relative flex max-h-[calc(100dvh-2rem)] w-full max-w-md flex-col rounded-(--radius-lg) border border-border bg-card p-6 shadow-(--shadow-lg) outline-none animate-panel-in',
          className,
        )}
      >
        <h2 id={titleId} className="shrink-0 font-display text-xl font-bold text-foreground">
          {title}
        </h2>
        {description && (
          <p id={descId} className="mt-1 shrink-0 text-sm text-muted-foreground">
            {description}
          </p>
        )}
        {/* Scrolls when content is tall. The inset padding keeps focus rings
            (outline + offset, 4px) from being clipped by the overflow. */}
        {children && (
          <div className="-mx-1.5 mt-3 min-h-0 overflow-y-auto px-1.5 py-1.5">{children}</div>
        )}
        {footer && (
          <div className="mt-5 flex shrink-0 flex-wrap justify-end gap-3">{footer}</div>
        )}
      </div>
    </div>
  );
}
