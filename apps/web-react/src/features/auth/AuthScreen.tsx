import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { signInWithEmailAndPassword, sendPasswordResetEmail } from 'firebase/auth';
import { auth } from '@/lib/firebase';
import { authErrorMessage } from '@/lib/authErrors';
import { AuthShell } from '@/components/ui/AuthShell';
import { Button } from '@/components/ui/Button';
import { TextField } from '@/components/ui/TextField';

type View = 'login' | 'forgot';

export function AuthScreen() {
  const [view, setView] = useState<View>('login');

  if (view === 'forgot') return <ForgotForm onBack={() => setView('login')} />;
  return <LoginForm onForgot={() => setView('forgot')} />;
}

/* ---------------------------------- Login ----------------------------------- */

function LoginForm({ onForgot }: { onForgot: () => void }) {
  const { t } = useTranslation();
  const schema = z.object({
    email: z.string().min(1, t('validation.emailRequired')).email(t('validation.emailInvalid')),
    password: z.string().min(1, t('validation.passwordRequired')),
  });
  type Values = z.infer<typeof schema>;
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<Values>({ resolver: zodResolver(schema) });

  async function onSubmit(values: Values) {
    try {
      await signInWithEmailAndPassword(auth, values.email.trim(), values.password);
    } catch (e) {
      toast.error(authErrorMessage(t, e));
    }
  }

  return (
    <AuthShell
      title={t('auth.welcomeBack')}
      subtitle={t('auth.loginSubtitle')}
      footer={null}
    >
      <form noValidate onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-4">
        <TextField
          label={t('auth.email')}
          type="email"
          autoComplete="email"
          autoFocus
          error={errors.email?.message}
          {...register('email')}
        />
        <TextField
          label={t('auth.password')}
          type="password"
          autoComplete="current-password"
          error={errors.password?.message}
          {...register('password')}
        />
        <div className="-mt-1 text-right">
          <button type="button" onClick={onForgot} className="text-sm font-medium text-primary hover:underline">
            {t('auth.forgotPassword')}
          </button>
        </div>
        <Button type="submit" size="lg" fullWidth loading={isSubmitting}>
          {t('auth.signIn')}
        </Button>
      </form>
    </AuthShell>
  );
}

/* ---------------------------------- Forgot ---------------------------------- */

function ForgotForm({ onBack }: { onBack: () => void }) {
  const { t } = useTranslation();
  const [sent, setSent] = useState(false);
  const schema = z.object({
    email: z.string().min(1, t('validation.emailRequired')).email(t('validation.emailInvalid')),
  });
  type Values = z.infer<typeof schema>;
  const {
    register,
    handleSubmit,
    getValues,
    formState: { errors, isSubmitting },
  } = useForm<Values>({ resolver: zodResolver(schema) });

  async function send(email: string) {
    await sendPasswordResetEmail(auth, email.trim());
  }

  async function onSubmit(values: Values) {
    try {
      await send(values.email);
      setSent(true);
    } catch (e) {
      toast.error(authErrorMessage(t, e));
    }
  }

  if (sent) {
    return (
      <AuthShell title={t('auth.resetSentTitle')} subtitle={t('auth.resetSentBody')}>
        <div className="flex flex-col gap-3">
          <div className="rounded-(--radius-md) bg-primary-light px-4 py-3 text-sm font-medium text-primary">
            {getValues('email').trim()}
          </div>
          <Button size="lg" fullWidth onClick={onBack}>
            {t('auth.backToSignIn')}
          </Button>
          <Button
            variant="ghost"
            onClick={async () => {
              try {
                await send(getValues('email'));
                toast.success(t('auth.emailResent'));
              } catch (e) {
                toast.error(authErrorMessage(t, e));
              }
            }}
          >
            {t('auth.resend')}
          </Button>
        </div>
      </AuthShell>
    );
  }

  return (
    <AuthShell
      title={t('auth.resetTitle')}
      subtitle={t('auth.resetSubtitle')}
      footer={
        <button type="button" onClick={onBack} className="font-semibold text-primary hover:underline">
          {t('auth.backToSignIn')}
        </button>
      }
    >
      <form noValidate onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-4">
        <TextField
          label={t('auth.email')}
          type="email"
          autoComplete="email"
          autoFocus
          error={errors.email?.message}
          {...register('email')}
        />
        <Button type="submit" size="lg" fullWidth loading={isSubmitting}>
          {t('auth.sendResetLink')}
        </Button>
      </form>
    </AuthShell>
  );
}
