import { type ReactNode } from 'react';
import { Logo } from './Logo';
import { lang, setLang, t, type Lang } from '@/i18n';

interface AuthShellProps {
  title: string;
  subtitle?: string;
  children: ReactNode;
  footer?: ReactNode;
}

/** Centered branded layout for unauthenticated / setup screens. */
export function AuthShell({ title, subtitle, children, footer }: AuthShellProps) {
  return (
    <div className="relative flex min-h-dvh flex-col items-center justify-center px-5 py-12">
      <LangToggle />
      <div
        aria-hidden
        className="pointer-events-none absolute inset-x-0 top-0 h-72 bg-gradient-to-b from-primary-light to-transparent"
      />
      <div className="relative flex w-full max-w-md flex-col items-center">
        <Logo />
        <span className="mt-5 text-[0.8125rem] font-semibold uppercase tracking-[0.08em] text-primary">
          Yoshi Vet Care
        </span>
        <h1 className="mt-2 text-center font-display text-3xl font-bold text-foreground">
          {title}
        </h1>
        {subtitle && (
          <p className="mt-2 max-w-sm text-center text-sm text-muted-foreground">
            {subtitle}
          </p>
        )}

        <div className="mt-8 w-full rounded-(--radius-lg) border border-border bg-card p-6 shadow-(--shadow-md) sm:p-7">
          {children}
        </div>

        {footer && <div className="mt-6 text-center text-sm">{footer}</div>}
      </div>
    </div>
  );
}

/** Small PT | EN text toggle shown on unauthenticated screens. */
function LangToggle() {
  const option = (l: Lang, label: string) => (
    <button
      type="button"
      onClick={() => l !== lang && setLang(l)}
      className={
        l === lang
          ? 'font-semibold text-foreground'
          : 'text-muted-foreground hover:text-foreground'
      }
      aria-pressed={l === lang}
    >
      {label}
    </button>
  );
  return (
    <div className="absolute right-4 top-4 flex items-center gap-1.5 text-sm" aria-label={t('auth.language')}>
      {option('pt', 'PT')}
      <span className="text-muted-foreground/50">|</span>
      {option('en', 'EN')}
    </div>
  );
}
