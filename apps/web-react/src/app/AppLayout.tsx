import { type ReactNode } from 'react';
import { NavLink } from 'react-router-dom';
import { LogOut, type LucideIcon } from 'lucide-react';
import { Logo } from '@/components/ui/Logo';
import { cn } from '@/lib/cn';
import { t } from '@/i18n';

export interface NavItem {
  to: string;
  label: string;
  icon: LucideIcon;
  end?: boolean;
  /** Count shown on the item (e.g. pending requests). Hidden when 0. */
  badge?: number;
}

function Badge({ n, className }: { n?: number; className?: string }) {
  if (!n) return null;
  return (
    <span
      className={cn(
        'grid h-5 min-w-5 place-items-center rounded-full bg-destructive px-1 text-[11px] font-semibold text-destructive-foreground',
        className,
      )}
    >
      {n}
    </span>
  );
}

interface AppLayoutProps {
  nav: NavItem[];
  userName: string;
  userSubtitle?: string;
  onSignOut: () => void;
  children: ReactNode;
}

export function AppLayout({
  nav,
  userName,
  userSubtitle,
  onSignOut,
  children,
}: AppLayoutProps) {
  return (
    <div className="min-h-dvh bg-background lg:grid lg:grid-cols-[260px_1fr]">
      <a
        href="#main-content"
        className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-[60] focus:rounded-(--radius-md) focus:bg-primary focus:px-4 focus:py-2 focus:text-sm focus:font-medium focus:text-primary-foreground focus:shadow-(--shadow-md)"
      >
        {t('nav.skip')}
      </a>
      {/* Sidebar (desktop) */}
      <aside className="sticky top-0 hidden h-dvh flex-col border-r border-border bg-card/60 px-4 py-6 lg:flex">
        <div className="flex items-center gap-2.5 px-2">
          <Logo size={36} />
          <span className="font-display text-lg font-semibold leading-tight text-foreground">Yoshi Vet Care</span>
        </div>
        <nav aria-label={t('nav.main')} className="mt-8 flex flex-1 flex-col gap-1">
          {nav.map((item) => (
            <NavItemLink key={item.to} item={item} />
          ))}
        </nav>
        <UserCard name={userName} subtitle={userSubtitle} onSignOut={onSignOut} />
      </aside>

      {/* Mobile top bar */}
      <header className="sticky top-0 z-30 flex items-center justify-between border-b border-border bg-card/80 px-4 py-3 backdrop-blur lg:hidden">
        <div className="flex items-center gap-2.5">
          <Logo size={32} />
          <span className="font-display text-base font-semibold leading-tight text-foreground">Yoshi Vet Care</span>
        </div>
        <button
          type="button"
          onClick={onSignOut}
          className="inline-flex h-9 w-9 items-center justify-center rounded-(--radius-md) text-muted-foreground hover:bg-secondary"
          aria-label={t('common.signOut')}
        >
          <LogOut size={18} />
        </button>
      </header>

      <div className="flex min-w-0 flex-col">
        <main
          id="main-content"
          className="mx-auto w-full max-w-6xl flex-1 px-4 py-6 pb-28 sm:px-6 lg:px-10 lg:py-10 lg:pb-10"
        >
          {children}
        </main>

        {/* Mobile bottom nav */}
        <nav
          aria-label={t('nav.main')}
          className="fixed inset-x-0 bottom-0 z-30 flex items-center justify-around border-t border-border bg-card/95 px-2 pb-[max(0.5rem,env(safe-area-inset-bottom))] pt-2 backdrop-blur lg:hidden"
        >
          {nav.map((item) => (
            <MobileNavItem key={item.to} item={item} />
          ))}
        </nav>
      </div>
    </div>
  );
}

function NavItemLink({ item }: { item: NavItem }) {
  const Icon = item.icon;
  return (
    <NavLink
      to={item.to}
      end={item.end}
      className={({ isActive }) =>
        cn(
          'flex items-center gap-3 rounded-(--radius-md) px-3 py-2.5 text-sm font-medium transition-colors',
          isActive
            ? 'bg-primary text-primary-foreground shadow-(--shadow-sm)'
            : 'text-muted-foreground hover:bg-secondary hover:text-foreground',
        )
      }
    >
      <Icon size={18} />
      {item.label}
      <Badge n={item.badge} className="ml-auto" />
    </NavLink>
  );
}

function MobileNavItem({ item }: { item: NavItem }) {
  const Icon = item.icon;
  return (
    <NavLink
      to={item.to}
      end={item.end}
      className={({ isActive }) =>
        cn(
          'flex flex-1 flex-col items-center gap-1 rounded-(--radius-sm) py-1.5 text-[11px] font-medium',
          isActive ? 'text-primary' : 'text-muted-foreground',
        )
      }
    >
      <span className="relative">
        <Icon size={20} />
        <Badge n={item.badge} className="absolute -right-3 -top-2" />
      </span>
      {item.label}
    </NavLink>
  );
}

function UserCard({
  name,
  subtitle,
  onSignOut,
}: {
  name: string;
  subtitle?: string;
  onSignOut: () => void;
}) {
  const initial = name.trim().charAt(0).toUpperCase() || '?';
  return (
    <div className="mt-4 flex items-center gap-3 rounded-(--radius-md) border border-border bg-card p-3">
      <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-primary-light font-semibold text-primary">
        {initial}
      </div>
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-medium text-foreground">{name}</p>
        {subtitle && (
          <p className="truncate text-xs text-muted-foreground">{subtitle}</p>
        )}
      </div>
      <button
        type="button"
        onClick={onSignOut}
        className="inline-flex h-8 w-8 items-center justify-center rounded-(--radius-sm) text-muted-foreground hover:bg-secondary hover:text-foreground"
        aria-label={t('common.signOut')}
      >
        <LogOut size={16} />
      </button>
    </div>
  );
}
