import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import {
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  sendEmailVerification,
  sendPasswordResetEmail,
  updateProfile as updateAuthProfile,
} from 'firebase/auth';
import { auth } from '@/lib/firebase';
import { authErrorMessage } from '@/lib/authErrors';
import { AuthShell } from '@/components/ui/AuthShell';
import { Button } from '@/components/ui/Button';
import { TextField } from '@/components/ui/TextField';

type View = 'login' | 'register' | 'forgot';

export function AuthScreen() {
  const [view, setView] = useState<View>('login');

  if (view === 'forgot') return <ForgotForm onBack={() => setView('login')} />;
  if (view === 'register')
    return <RegisterForm onSwitch={() => setView('login')} />;
  return (
    <LoginForm
      onRegister={() => setView('register')}
      onForgot={() => setView('forgot')}
    />
  );
}

/* ---------------------------------- Login ----------------------------------- */

function LoginForm({
  onRegister,
  onForgot,
}: {
  onRegister: () => void;
  onForgot: () => void;
}) {
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
      footer={
        <span className="text-muted-foreground">
          {t('auth.noAccount')}{' '}
          <button type="button" onClick={onRegister} className="font-semibold text-primary hover:underline">
            {t('auth.signUp')}
          </button>
        </span>
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

/* --------------------------------- Register --------------------------------- */

function RegisterForm({ onSwitch }: { onSwitch: () => void }) {
  const { t } = useTranslation();
  const schema = z
    .object({
      name: z.string().trim().min(1, t('validation.nameRequired')).min(2, t('validation.nameMin')),
      email: z.string().min(1, t('validation.emailRequired')).email(t('validation.emailInvalid')),
      password: z.string().min(1, t('validation.passwordRequired')).min(6, t('validation.passwordMin')),
      confirm: z.string().min(1, t('validation.confirmRequired')),
    })
    .refine((v) => v.password === v.confirm, {
      path: ['confirm'],
      message: t('validation.passwordsMismatch'),
    });
  type Values = z.infer<typeof schema>;
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<Values>({ resolver: zodResolver(schema) });

  async function onSubmit(values: Values) {
    try {
      const cred = await createUserWithEmailAndPassword(
        auth,
        values.email.trim(),
        values.password,
      );
      await updateAuthProfile(cred.user, { displayName: values.name.trim() });
      await sendEmailVerification(cred.user);
      toast.success(t('auth.accountCreated'));
    } catch (e) {
      toast.error(authErrorMessage(t, e));
    }
  }

  return (
    <AuthShell
      title={t('auth.createYourAccount')}
      subtitle={t('auth.registerSubtitle')}
      footer={
        <span className="text-muted-foreground">
          {t('auth.haveAccount')}{' '}
          <button type="button" onClick={onSwitch} className="font-semibold text-primary hover:underline">
            {t('auth.signIn')}
          </button>
        </span>
      }
    >
      <form noValidate onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-4">
        <TextField
          label={t('auth.fullName')}
          autoComplete="name"
          autoFocus
          error={errors.name?.message}
          {...register('name')}
        />
        <TextField
          label={t('auth.email')}
          type="email"
          autoComplete="email"
          error={errors.email?.message}
          {...register('email')}
        />
        <TextField
          label={t('auth.password')}
          type="password"
          autoComplete="new-password"
          error={errors.password?.message}
          {...register('password')}
        />
        <TextField
          label={t('auth.confirmPassword')}
          type="password"
          autoComplete="new-password"
          error={errors.confirm?.message}
          {...register('confirm')}
        />
        <Button type="submit" size="lg" fullWidth loading={isSubmitting}>
          {t('auth.signUp')}
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
