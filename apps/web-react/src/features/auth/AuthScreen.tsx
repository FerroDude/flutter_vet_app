import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { toast } from 'sonner';
import { signInWithEmailAndPassword, sendPasswordResetEmail } from 'firebase/auth';
import { auth } from '@/lib/firebase';
import { authErrorMessage } from '@/lib/authErrors';
import { AuthShell } from '@/components/ui/AuthShell';
import { Button } from '@/components/ui/Button';
import { TextField } from '@/components/ui/TextField';

const email = z.string().min(1, 'Indique o email.').email('Email inválido.');

export function AuthScreen() {
  const [view, setView] = useState<'login' | 'forgot'>('login');
  return view === 'forgot' ? (
    <ForgotForm onBack={() => setView('login')} />
  ) : (
    <LoginForm onForgot={() => setView('forgot')} />
  );
}

const loginSchema = z.object({
  email,
  password: z.string().min(1, 'Indique a palavra-passe.'),
});

function LoginForm({ onForgot }: { onForgot: () => void }) {
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<z.infer<typeof loginSchema>>({ resolver: zodResolver(loginSchema) });

  const onSubmit = handleSubmit(async (v) => {
    try {
      await signInWithEmailAndPassword(auth, v.email.trim(), v.password);
    } catch (e) {
      toast.error(authErrorMessage(e));
    }
  });

  return (
    <AuthShell title="Bem-vindo" subtitle="Entre na sua conta Vet+.">
      <form noValidate onSubmit={onSubmit} className="flex flex-col gap-4">
        <TextField
          label="Email"
          type="email"
          autoComplete="email"
          autoFocus
          error={errors.email?.message}
          {...register('email')}
        />
        <TextField
          label="Palavra-passe"
          type="password"
          autoComplete="current-password"
          error={errors.password?.message}
          {...register('password')}
        />
        <div className="-mt-1 text-right">
          <button type="button" onClick={onForgot} className="text-sm font-medium text-primary hover:underline">
            Esqueceu-se da palavra-passe?
          </button>
        </div>
        <Button type="submit" size="lg" fullWidth loading={isSubmitting}>
          Entrar
        </Button>
      </form>
    </AuthShell>
  );
}

const forgotSchema = z.object({ email });

function ForgotForm({ onBack }: { onBack: () => void }) {
  const [sentTo, setSentTo] = useState<string | null>(null);
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<z.infer<typeof forgotSchema>>({ resolver: zodResolver(forgotSchema) });

  const send = async (to: string) => {
    try {
      await sendPasswordResetEmail(auth, to);
      return true;
    } catch (e) {
      toast.error(authErrorMessage(e));
      return false;
    }
  };

  const onSubmit = handleSubmit(async (v) => {
    const to = v.email.trim();
    if (await send(to)) setSentTo(to);
  });

  if (sentTo) {
    return (
      <AuthShell title="Veja o email" subtitle="Enviámos um link para definir a palavra-passe.">
        <div className="flex flex-col gap-3">
          <div className="rounded-(--radius-md) bg-primary-light px-4 py-3 text-sm font-medium text-primary">
            {sentTo}
          </div>
          <Button size="lg" fullWidth onClick={onBack}>
            Voltar a entrar
          </Button>
          <Button
            variant="ghost"
            onClick={async () => {
              if (await send(sentTo)) toast.success('Email enviado.');
            }}
          >
            Não chegou? Reenviar
          </Button>
        </div>
      </AuthShell>
    );
  }

  return (
    <AuthShell
      title="Repor palavra-passe"
      subtitle="Indique o email e enviamos um link para definir uma nova palavra-passe."
      footer={
        <button type="button" onClick={onBack} className="font-semibold text-primary hover:underline">
          Voltar a entrar
        </button>
      }
    >
      <form noValidate onSubmit={onSubmit} className="flex flex-col gap-4">
        <TextField
          label="Email"
          type="email"
          autoComplete="email"
          autoFocus
          error={errors.email?.message}
          {...register('email')}
        />
        <Button type="submit" size="lg" fullWidth loading={isSubmitting}>
          Enviar link
        </Button>
      </form>
    </AuthShell>
  );
}
