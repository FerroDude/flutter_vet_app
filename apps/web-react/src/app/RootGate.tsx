import { useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { useAuth, needsDisplayName } from '@/auth/AuthProvider';
import { initForegroundMessages, syncPushToken } from '@/lib/messaging';
import { PageSpinner } from '@/components/Spinner';
import { Placeholder } from '@/components/Placeholder';
import { Button } from '@/components/ui/Button';
import { isFirebaseConfigured } from '@/lib/env';
import { AuthScreen } from '@/features/auth/AuthScreen';
import { VerifyEmailScreen } from '@/features/auth/VerifyEmailScreen';
import { DisplayNameScreen } from '@/features/auth/DisplayNameScreen';
import { PetOwnerApp } from './PetOwnerApp';
import { StaffApp } from './StaffApp';

/**
 * Top-level routing gate. Mirrors the decision tree from the Flutter
 * AuthWrapper (apps/mobile-flutter/lib/core/auth/auth_wrapper.dart):
 *   not signed in            -> auth screens
 *   signed in, !verified     -> email verification
 *   profile loading / error  -> spinner / retry
 *   no profile               -> no-access error
 *   vet                      -> display-name setup (if missing) -> home
 *   petOwner (client)        -> home
 */
export function RootGate() {
  const { t } = useTranslation();
  const {
    loading,
    profileLoading,
    error,
    firebaseUser,
    emailVerified,
    profile,
    role,
    refreshProfile,
    signOutUser,
  } = useAuth();

  const uid = firebaseUser?.uid;
  const canPush = Boolean(uid && emailVerified && profile);
  useEffect(() => {
    if (!canPush || !uid) return;
    void initForegroundMessages();
    void syncPushToken(uid);
  }, [canPush, uid]);

  if (!isFirebaseConfigured) {
    return (
      <Placeholder
        title="Firebase não configurado"
        subtitle="Copie .env.example para .env.local, preencha a config da app Web na consola Firebase (projeto: vetplus-digital) e reinicie o servidor."
      />
    );
  }

  if (loading) return <PageSpinner />;
  if (!firebaseUser) return <AuthScreen />;
  if (!emailVerified) return <VerifyEmailScreen />;

  if (error) {
    return (
      <div className="mx-auto flex min-h-dvh max-w-md flex-col items-center justify-center gap-4 px-6 text-center">
        <h1 className="font-display text-2xl font-bold text-foreground">
          {t('errors.generic')}
        </h1>
        <p className="text-sm text-muted-foreground">{error}</p>
        <div className="flex gap-2">
          <Button onClick={() => void refreshProfile()}>{t('common.retry')}</Button>
          <Button variant="outline" onClick={() => void signOutUser()}>
            Terminar sessão
          </Button>
        </div>
      </div>
    );
  }

  if (profileLoading || !profile) {
    return <PageSpinner />;
  }

  if (role === 'vet' && needsDisplayName(profile)) {
    return <DisplayNameScreen />;
  }

  if (role === 'petOwner') {
    return <PetOwnerApp />;
  }

  if (role === 'vet') {
    return <StaffApp />;
  }

  return (
    <Placeholder
      title="Bem-vindo"
      subtitle="Esta conta ainda não tem um papel definido. Contacte o suporte se isto parecer errado."
    />
  );
}
