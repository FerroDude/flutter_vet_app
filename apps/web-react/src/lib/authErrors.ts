import type { TFunction } from 'i18next';

/** Map a thrown Firebase Auth error to a localized, user-facing message. */
export function authErrorMessage(t: TFunction, e: unknown): string {
  const code =
    e && typeof e === 'object' && 'code' in e ? String((e as { code: unknown }).code) : '';
  if (code) {
    const msg = t(`errors.${code}`, { defaultValue: '' });
    if (msg) return msg;
  }
  return t('errors.generic');
}
