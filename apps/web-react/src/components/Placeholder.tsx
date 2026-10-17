import { useTranslation } from 'react-i18next';

interface PlaceholderProps {
  title: string;
  subtitle?: string;
}

/**
 * Generic "screen scaffolded, content coming in a later phase" placeholder.
 * Demonstrates the design tokens (serif heading, teal accent, soft card).
 */
export function Placeholder({ title, subtitle }: PlaceholderProps) {
  const { t } = useTranslation();
  return (
    <div className="mx-auto flex min-h-dvh max-w-2xl flex-col items-center justify-center gap-4 px-6 text-center">
      <span className="text-[0.8125rem] font-semibold uppercase tracking-[0.06em] text-primary">
        {t('common.appName')}
      </span>
      <h1 className="font-display text-4xl font-bold text-foreground">{title}</h1>
      <p className="max-w-md text-muted-foreground">
        {subtitle ?? t('placeholder.phase')}
      </p>
      <span className="mt-2 inline-flex items-center rounded-(--radius-pill) bg-primary-light px-4 py-1.5 text-sm font-medium text-primary">
        {t('placeholder.comingSoon')}
      </span>
    </div>
  );
}
