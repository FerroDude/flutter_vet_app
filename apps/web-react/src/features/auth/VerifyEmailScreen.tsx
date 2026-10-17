import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { sendEmailVerification } from 'firebase/auth';
import { auth } from '@/lib/firebase';
import { useAuth } from '@/auth/AuthProvider';
import { authErrorMessage } from '@/lib/authErrors';
import { AuthShell } from '@/components/ui/AuthShell';
import { Button } from '@/components/ui/Button';

export function VerifyEmailScreen() {
  const { t } = useTranslation();
  const { firebaseUser, reloadFirebaseUser, signOutUser } = useAuth();
  const [checking, setChecking] = useState(false);
  const [resending, setResending] = useState(false);

  // Poll for verification in the background; switches screens automatically
  // once the link is clicked (onAuthStateChanged won't fire on its own).
  useEffect(() => {
    const id = setInterval(() => {
      void reloadFirebaseUser();
    }, 5000);
    return () => clearInterval(id);
  }, [reloadFirebaseUser]);

  async function check() {
    setChecking(true);
    try {
      await reloadFirebaseUser();
      if (!auth.currentUser?.emailVerified) {
        toast.message(t('auth.stillNotVerified'));
      }
    } finally {
      setChecking(false);
    }
  }

  async function resend() {
    if (!auth.currentUser) return;
    setResending(true);
    try {
      await sendEmailVerification(auth.currentUser);
      toast.success(t('auth.emailResent'));
    } catch (e) {
      toast.error(authErrorMessage(t, e));
    } finally {
      setResending(false);
    }
  }

  return (
    <AuthShell
      title={t('auth.verifyEmailTitle')}
      subtitle={t('auth.verifyInstructions')}
      footer={
        <button type="button" onClick={() => void signOutUser()} className="font-medium text-muted-foreground hover:text-foreground">
          {t('auth.signOutDifferent')}
        </button>
      }
    >
      <div className="flex flex-col gap-4">
        <div className="rounded-(--radius-md) bg-primary-light px-4 py-3 text-center text-sm">
          <span className="text-muted-foreground">{t('auth.verifySentTo')}</span>
          <br />
          <span className="font-semibold text-primary">{firebaseUser?.email}</span>
        </div>
        <Button size="lg" fullWidth loading={checking} onClick={check}>
          {t('auth.iVerified')}
        </Button>
        <Button variant="outline" fullWidth loading={resending} onClick={resend}>
          {t('auth.resendEmail')}
        </Button>
      </div>
    </AuthShell>
  );
}
