import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react';
import { cn } from '@/lib/cn';

export interface MenuItem {
  label: string;
  icon?: ReactNode;
  onClick: () => void;
  danger?: boolean;
}

const MENU_HEIGHT = 240;

/**
 * Small action menu. Positioned `fixed` from the trigger so scroll containers
 * never clip it; opens upward when there's no room below.
 */
export function Menu({
  label,
  trigger,
  items,
  header,
  align = 'right',
  triggerClassName,
}: {
  label: string;
  trigger: ReactNode;
  items: MenuItem[];
  /** Extra content above the items (e.g. emoji reactions). */
  header?: (close: () => void) => ReactNode;
  align?: 'left' | 'right';
  triggerClassName?: string;
}) {
  const btnRef = useRef<HTMLButtonElement>(null);
  const [style, setStyle] = useState<CSSProperties | null>(null);
  const close = () => setStyle(null);

  useEffect(() => {
    if (!style) return;
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && close();
    window.addEventListener('keydown', onKey);
    window.addEventListener('resize', close);
    window.addEventListener('scroll', close, true);
    return () => {
      window.removeEventListener('keydown', onKey);
      window.removeEventListener('resize', close);
      window.removeEventListener('scroll', close, true);
    };
  }, [style]);

  const open = () => {
    const r = btnRef.current?.getBoundingClientRect();
    if (!r) return;
    const up = r.bottom + MENU_HEIGHT > window.innerHeight && r.top > MENU_HEIGHT;
    setStyle({
      position: 'fixed',
      ...(up ? { bottom: window.innerHeight - r.top + 4 } : { top: r.bottom + 4 }),
      ...(align === 'right'
        ? { right: Math.max(8, window.innerWidth - r.right) }
        : { left: Math.max(8, r.left) }),
    });
  };

  return (
    <>
      <button
        ref={btnRef}
        type="button"
        aria-label={label}
        aria-haspopup="menu"
        aria-expanded={style !== null}
        onClick={() => (style ? close() : open())}
        className={cn(
          'grid h-8 w-8 shrink-0 place-items-center rounded-full text-muted-foreground hover:bg-secondary hover:text-foreground',
          triggerClassName,
        )}
      >
        {trigger}
      </button>
      {style && (
        <>
          <button
            type="button"
            aria-label="Fechar menu"
            className="fixed inset-0 z-40 cursor-default"
            onClick={close}
          />
          <div
            role="menu"
            style={style}
            className="z-50 w-48 overflow-hidden rounded-(--radius-md) border border-border bg-card py-1 shadow-(--shadow-md)"
          >
            {header?.(close)}
            {items.map((it) => (
              <button
                key={it.label}
                type="button"
                role="menuitem"
                onClick={() => {
                  close();
                  it.onClick();
                }}
                className={cn(
                  'flex w-full items-center gap-2 px-3 py-2 text-left text-sm hover:bg-secondary',
                  it.danger ? 'text-destructive' : 'text-foreground',
                )}
              >
                {it.icon}
                {it.label}
              </button>
            ))}
          </div>
        </>
      )}
    </>
  );
}
