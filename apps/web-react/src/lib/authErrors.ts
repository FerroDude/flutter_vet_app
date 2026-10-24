import { t, type TKey } from '@/i18n';

const KEY_FOR: Record<string, TKey> = {
  'auth/invalid-email': 'auth.error.invalid-email',
  'auth/user-disabled': 'auth.error.user-disabled',
  'auth/user-not-found': 'auth.error.user-not-found',
  'auth/wrong-password': 'auth.error.wrong-password',
  'auth/invalid-credential': 'auth.error.invalid-credential',
  'auth/too-many-requests': 'auth.error.too-many-requests',
  'auth/operation-not-allowed': 'auth.error.operation-not-allowed',
};

/** Map a thrown Firebase Auth error to a user-facing message. */
export function authErrorMessage(e: unknown): string {
  const code = e && typeof e === 'object' && 'code' in e ? String((e as { code: unknown }).code) : '';
  const key = KEY_FOR[code];
  return key ? t(key) : t('errors.generic');
}
