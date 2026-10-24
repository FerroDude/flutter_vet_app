import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { toast } from 'sonner';
import { useAuth } from '@/auth/AuthProvider';
import { t } from '@/i18n';
import { AuthShell } from '@/components/ui/AuthShell';
import { Button } from '@/components/ui/Button';
import { TextField } from '@/components/ui/TextField';

const schema = z.object({
  name: z.string().trim().min(2, t('auth.nameTooShort')),
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
      toast.error(t('errors.generic'));
    }
  });

  return (
    <AuthShell title={t('auth.name.title')} subtitle={t('auth.name.subtitle')}>
      <form noValidate onSubmit={onSubmit} className="flex flex-col gap-4">
        <TextField
          label={t('common.name')}
          placeholder={t('auth.namePlaceholder')}
          autoFocus
          error={errors.name?.message}
          {...register('name')}
        />
        <Button type="submit" size="lg" fullWidth loading={isSubmitting}>
          {t('auth.continue')}
        </Button>
      </form>
    </AuthShell>
  );
}
