import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { toast } from 'sonner';
import { useAuth } from '@/auth/AuthProvider';
import { GENERIC_ERROR } from '@/lib/authErrors';
import { AuthShell } from '@/components/ui/AuthShell';
import { Button } from '@/components/ui/Button';
import { TextField } from '@/components/ui/TextField';

const schema = z.object({
  name: z.string().trim().min(2, 'O nome tem de ter pelo menos 2 caracteres.'),
});

export function DisplayNameScreen() {
  const { updateProfile } = useAuth();
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<z.infer<typeof schema>>({ resolver: zodResolver(schema) });

  const onSubmit = handleSubmit(async (v) => {
    try {
      await updateProfile({ displayName: v.name.trim() });
    } catch {
      toast.error(GENERIC_ERROR);
    }
  });

  return (
    <AuthShell title="O seu nome" subtitle="É assim que os clientes veem o seu nome.">
      <form noValidate onSubmit={onSubmit} className="flex flex-col gap-4">
        <TextField
          label="Nome"
          placeholder="O seu nome"
          autoFocus
          error={errors.name?.message}
          {...register('name')}
        />
        <Button type="submit" size="lg" fullWidth loading={isSubmitting}>
          Continuar
        </Button>
      </form>
    </AuthShell>
  );
}
