import { useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { useAuth, needsDisplayName } from '@/auth/AuthProvider';
import { initForegroundMessages, syncPushToken } from '@/lib/messaging';
import { PageSpinner } from '@/components/Spinner';
import { Placeholder } from '@/components/Placeholder';
import { Button } from '@/components/ui/Button';
import { isFirebaseConfigured } from '@/lib/env';
import { isPetOwner } from '@vetplus/shared';
import { AuthScreen } from '@/features/auth/AuthScreen';
import { VerifyEmailScreen } from '@/features/auth/VerifyEmailScreen';
import { DisplayNameScreen } from '@/features/auth/DisplayNameScreen';
import { ClinicSelectionScreen } from '@/features/clinics/ClinicSelectionScreen';
import { PetOwnerApp } from './PetOwnerApp';
import { StaffApp } from './StaffApp';
import { AppOwnerApp } from './AppOwnerApp';

/**
 * Top-level routing gate. Mirrors the decision tree from the Flutter
 * AuthWrapper (apps/mobile-flutter/lib/core/auth/auth_wrapper.dart):
 *   not signed in            -> auth screens
 *   signed in, !verified     -> email verification
 *   profile loading / error  -> spinner / retry
 *   appOwner / clinicAdmin   -> dashboard
 *   vet / receptionist       -> display-name setup (if missing) -> home
 *   petOwner (no clinic)     -> clinic selection
 *   petOwner                 -> home
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
        title="Firebase not configured"
        subtitle="Copy .env.example to .env.local and fill in the Web app config from the Firebase console (project: vetplus-digital), then restart the dev server."
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
        <Button onClick={() => void refreshProfile()}>{t('common.retry')}</Button>
      </div>
    );
  }

  if (profileLoading || !profile) {
    return <PageSpinner />;
  }

  // Staff must set a display name on first login.
  if ((role === 'vet' || role === 'receptionist') && needsDisplayName(profile)) {
    return <DisplayNameScreen />;
  }

  // Pet owners pick a clinic (or skip) before reaching home.
  if (
    isPetOwner(profile) &&
    !profile.connectedClinicId &&
    !profile.hasSkippedClinicSelection
  ) {
    return <ClinicSelectionScreen />;
  }

  if (role === 'petOwner') {
    return <PetOwnerApp />;
  }

  if (role === 'receptionist' || role === 'vet' || role === 'clinicAdmin') {
    return <StaffApp />;
  }

  if (role === 'appOwner') {
    return <AppOwnerApp />;
  }

  return (
    <Placeholder
      title="Welcome"
      subtitle="Your account isn't set up for a role yet. Contact support if this seems wrong."
    />
  );
}
