import { type ReactNode } from 'react';

interface PageHeaderProps {
  title: string;
  /** Small uppercase tracked label above the title (editorial eyebrow). */
  eyebrow?: string;
  subtitle?: string;
  actions?: ReactNode;
}

export function PageHeader({ title, eyebrow, subtitle, actions }: PageHeaderProps) {
  return (
    <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
      <div className="min-w-0">
        {eyebrow && <p className="eyebrow mb-1.5">{eyebrow}</p>}
        <h1 className="display-title text-[1.75rem] text-foreground sm:text-[2rem]">{title}</h1>
        {subtitle && <p className="mt-1.5 max-w-prose text-muted-foreground">{subtitle}</p>}
      </div>
      {actions && <div className="flex items-center gap-2">{actions}</div>}
    </div>
  );
}
