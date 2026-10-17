import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { useAuth } from '@/auth/AuthProvider';
import { AuthShell } from '@/components/ui/AuthShell';
import { Button } from '@/components/ui/Button';
import { TextField } from '@/components/ui/TextField';

export function DisplayNameScreen() {
  const { t } = useTranslation();
  const { updateProfile } = useAuth();
  const schema = z.object({
    name: z.string().trim().min(1, t('validation.nameRequired')).min(2, t('validation.nameMin')),
  });
  type Values = z.infer<typeof schema>;
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<Values>({ resolver: zodResolver(schema) });

  async function onSubmit(values: Values) {
    try {
      await updateProfile({ displayName: values.name.trim() });
      toast.success(t('auth.displayNameSaved'));
    } catch {
      toast.error(t('errors.generic'));
    }
  }

  return (
    <AuthShell title={t('auth.displayNameTitle')} subtitle={t('auth.displayNameSubtitle')}>
      <form noValidate onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-4">
        <TextField
          label={t('auth.displayName')}
          placeholder={t('auth.displayNamePlaceholder')}
          autoFocus
          error={errors.name?.message}
          {...register('name')}
        />
        <Button type="submit" size="lg" fullWidth loading={isSubmitting}>
          {t('common.continue')}
        </Button>
      </form>
    </AuthShell>
  );
}
