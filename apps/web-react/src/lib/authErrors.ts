const MESSAGES: Record<string, string> = {
  'auth/invalid-email': 'O email não é válido.',
  'auth/user-disabled': 'Esta conta está desativada.',
  'auth/user-not-found': 'Não existe conta com este email.',
  'auth/wrong-password': 'Email ou palavra-passe incorretos.',
  'auth/invalid-credential': 'Email ou palavra-passe incorretos.',
  'auth/too-many-requests': 'Demasiadas tentativas. Tente mais tarde.',
  'auth/operation-not-allowed': 'O início de sessão por email não está ativo.',
};

export const GENERIC_ERROR = 'Algo correu mal. Tente de novo.';

/** Map a thrown Firebase Auth error to a user-facing message. */
export function authErrorMessage(e: unknown): string {
  const code = e && typeof e === 'object' && 'code' in e ? String((e as { code: unknown }).code) : '';
  return MESSAGES[code] ?? GENERIC_ERROR;
}
