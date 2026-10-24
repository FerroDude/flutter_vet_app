import { useEffect, useState } from 'react';
import { cn } from '@/lib/cn';
import { t } from '@/i18n';

interface SpinnerProps {
  size?: number;
  className?: string;
  /** Rotation period in seconds. Higher = slower/calmer. */
  durationSec?: number;
}

/** Inline spinner (e.g. inside buttons). */
export function Spinner({ size = 20, className, durationSec = 0.7 }: SpinnerProps) {
  return (
    <span
      role="status"
      aria-label={t('common.loading')}
      data-spinner=""
      style={{ width: size, height: size, animationDuration: `${durationSec}s` }}
      className={cn(
        'inline-block animate-spin rounded-full border-2 border-current/25 border-t-current',
        className,
      )}
    />
  );
}

/**
 * Full-viewport centered loader. Waits `delayMs` before appearing so quick
 * loads don't flash a spinner, then fades in. Spins at a calmer pace.
 */
export function PageSpinner({ delayMs = 200 }: { delayMs?: number }) {
  const [show, setShow] = useState(delayMs === 0);

  useEffect(() => {
    if (delayMs === 0) return;
    const t = setTimeout(() => setShow(true), delayMs);
    return () => clearTimeout(t);
  }, [delayMs]);

  return (
    <div
      className={cn(
        'flex min-h-dvh items-center justify-center bg-background text-primary',
        'transition-opacity duration-300 motion-reduce:transition-none',
        show ? 'opacity-100' : 'opacity-0',
      )}
    >
      <Spinner size={32} durationSec={1.6} />
    </div>
  );
}
