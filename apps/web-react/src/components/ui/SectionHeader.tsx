import { type ReactNode } from 'react';
import { cn } from '@/lib/cn';

interface SectionHeaderProps {
  /** Small uppercase tracked label above the title (the editorial "eyebrow"). */
  eyebrow?: string;
  title: string;
  /** Heading level — keep the document outline sequential. */
  as?: 'h1' | 'h2' | 'h3';
  /** Optional trailing action (e.g. an "Add" button), right-aligned. */
  action?: ReactNode;
  className?: string;
}

const titleSize: Record<NonNullable<SectionHeaderProps['as']>, string> = {
  h1: 'text-[1.75rem] sm:text-[2rem]',
  h2: 'text-xl',
  h3: 'text-base',
};

/**
 * Eyebrow + title section header. Gives each section a deliberate rhythm
 * (label → title) instead of a flat stack of identical bold headings, which is
 * one of the strongest tells of generated UI.
 */
export function SectionHeader({
  eyebrow,
  title,
  as = 'h2',
  action,
  className,
}: SectionHeaderProps) {
  const Heading = as;
  return (
    <div className={cn('flex items-end justify-between gap-4', className)}>
      <div className="min-w-0">
        {eyebrow && <p className="eyebrow mb-1.5">{eyebrow}</p>}
        <Heading
          className={cn(
            'font-display font-semibold text-foreground',
            as === 'h1' && 'display-title font-medium',
            titleSize[as],
          )}
        >
          {title}
        </Heading>
      </div>
      {action && <div className="shrink-0">{action}</div>}
    </div>
  );
}
