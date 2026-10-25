import { useEffect, useMemo, useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useNavigate, useParams } from 'react-router-dom';
import { toast } from 'sonner';
import { ArrowLeft } from 'lucide-react';
import { useAuth } from '@/auth/AuthProvider';
import {
  addPet,
  updatePet,
  deletePet,
  petDoc,
  mapPet,
  uploadPetPhoto,
  removePetPhoto,
  type PetFields,
  type Pet,
} from '@/lib/petService';
import { useDoc } from '@/lib/useFirestore';
import { errorMessage } from '@/lib/format';
import { t } from '@/i18n';
import { PetPhotoPicker } from './PetPhotoPicker';
import { refreshPetTag } from '@/lib/petTagService';
import { TextField } from '@/components/ui/TextField';
import { Select } from '@/components/ui/Select';
import { Button } from '@/components/ui/Button';
import { Card, CardBody } from '@/components/ui/Card';
import { Dialog } from '@/components/ui/Dialog';
import { PageSpinner } from '@/components/Spinner';

const schema = z.object({
  name: z.string().trim().min(1, t('pets.nameRequired')),
  species: z.string().trim().min(1, t('pets.speciesRequired')),
  breed: z.string().trim().min(1, t('pets.breedRequired')),
  gender: z.enum(['Male', 'Female', 'Unknown']),
  dateOfBirth: z.string().optional(),
  weight: z.string().optional(),
  color: z.string().optional(),
  microchip: z.string().optional(),
});

type FormValues = z.infer<typeof schema>;

function toDateInput(d: Date | null): string {
  if (!d) return '';
  const m = `${d.getMonth() + 1}`.padStart(2, '0');
  const day = `${d.getDate()}`.padStart(2, '0');
  return `${d.getFullYear()}-${m}-${day}`;
}

function fromDateInput(value?: string): Date | null {
  if (!value) return null;
  const [y, m, d] = value.split('-').map(Number);
  if (!y || !m || !d) return null;
  return new Date(y, m - 1, d);
}

export function PetForm() {
  const { petId, ownerId: ownerParam } = useParams<{ petId: string; ownerId?: string }>();
  const isEdit = Boolean(petId);
  const navigate = useNavigate();
  const { firebaseUser, role } = useAuth();
  const uid = ownerParam || firebaseUser?.uid || '';
  const isVetView = role === 'vet' && Boolean(ownerParam);
  const petBase = isVetView ? `/clients/${ownerParam}/pets` : '/pets';

  const ref = useMemo(
    () => (isEdit && uid ? petDoc(uid, petId!) : null),
    [isEdit, uid, petId],
  );
  const { data: existing, loading } = useDoc<Pet>(ref, mapPet);

  const {
    register,
    handleSubmit,
    reset,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { gender: 'Unknown' },
  });

  const [hydrated, setHydrated] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [photoBlob, setPhotoBlob] = useState<Blob | null>(null);
  const [removePhoto, setRemovePhoto] = useState(false);
  useEffect(() => {
    if (isEdit && existing && !hydrated) {
      reset({
        name: existing.name,
        species: existing.species,
        breed: existing.breed,
        gender: existing.gender,
        dateOfBirth: toDateInput(existing.dateOfBirth),
        weight: existing.weight,
        color: existing.color,
        microchip: existing.microchip,
      });
      setHydrated(true);
    }
  }, [isEdit, existing, hydrated, reset]);

  if (isEdit && loading) return <PageSpinner />;

  const onSubmit = async (values: FormValues) => {
    if (!uid) return;
    const fields: PetFields = {
      name: values.name,
      species: values.species,
      breed: values.breed,
      gender: values.gender,
      dateOfBirth: fromDateInput(values.dateOfBirth),
      weight: values.weight ?? '',
      color: values.color ?? '',
      microchip: values.microchip ?? '',
      veterinarian: existing?.veterinarian ?? '',
      medicalNotes: existing?.medicalNotes ?? '',
      emergencyContact: existing?.emergencyContact ?? '',
    };
    try {
      const id = isEdit ? petId! : await addPet(uid, fields);
      if (isEdit) await updatePet(uid, id, fields);

      let photoError: string | null = null;
      if (photoBlob) {
        try {
          await uploadPetPhoto(uid, id, photoBlob);
        } catch (e) {
          photoError = errorMessage(e);
        }
      } else if (removePhoto) {
        await removePetPhoto(uid, id);
      }

      // Keep the public QR tag fresh (owner only; vet edits never touch tags).
      void refreshPetTag(uid, id);

      toast.success(isEdit ? t('pets.updated') : t('pets.added'));
      if (photoError) toast.error(t('pets.photoFailed', { error: photoError }));
      // New pet → back to the list of pets (client: Animais; vet: the client page).
      navigate(isEdit ? `${petBase}/${id}` : isVetView ? `/clients/${ownerParam}` : '/pets');
    } catch (e) {
      toast.error(errorMessage(e));
    }
  };

  const onDelete = async () => {
    if (!uid || !petId) return;
    setDeleting(true);
    try {
      await deletePet(uid, petId);
      toast.success(t('pets.deleted'));
      navigate('/pets');
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t('pets.deleteFailed'));
      setDeleting(false);
    }
  };

  return (
    <div className="mx-auto max-w-2xl">
      <button
        type="button"
        onClick={() => navigate(-1)}
        className="mb-4 inline-flex items-center gap-1.5 text-sm font-medium text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft size={16} /> {t('common.back')}
      </button>
      <h1 className="mb-6 font-display text-3xl font-bold text-foreground">
        {isEdit ? t('pets.edit') : t('pets.new')}
      </h1>

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
        {!isVetView && (
          <Card>
            <CardBody className="space-y-4">
              <p className="text-sm font-semibold text-foreground">{t('pets.photo')}</p>
              <PetPhotoPicker
                photoUrl={removePhoto ? null : (existing?.photoUrl ?? null)}
                photo={photoBlob}
                name={watch('name') || existing?.name || ''}
                disabled={isSubmitting}
                onPick={(b) => {
                  setPhotoBlob(b);
                  setRemovePhoto(false);
                }}
                onRemove={() => {
                  setPhotoBlob(null);
                  if (existing?.photoUrl) setRemovePhoto(true);
                }}
              />
            </CardBody>
          </Card>
        )}

        <Card>
          <CardBody className="space-y-4">
            <p className="text-sm font-semibold text-foreground">{t('pets.data')}</p>
            <TextField label={t('common.name')} error={errors.name?.message} {...register('name')} />
            <div className="grid gap-4 sm:grid-cols-2">
              <TextField
                label={t('pets.species')}
                placeholder={t('pets.speciesPlaceholder')}
                error={errors.species?.message}
                {...register('species')}
              />
              <TextField
                label={t('pets.breed')}
                error={errors.breed?.message}
                {...register('breed')}
              />
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <Select label={t('pets.sex')} error={errors.gender?.message} {...register('gender')}>
                <option value="Male">{t('pets.male')}</option>
                <option value="Female">{t('pets.female')}</option>
                <option value="Unknown">{t('pets.unknownGender')}</option>
              </Select>
              <TextField
                label={t('pets.dob')}
                type="date"
                error={errors.dateOfBirth?.message}
                {...register('dateOfBirth')}
              />
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <TextField
                label={t('pets.weight')}
                placeholder={t('pets.weightPlaceholder')}
                {...register('weight')}
              />
              <TextField
                label={t('pets.color')}
                placeholder={t('pets.colorPlaceholder')}
                {...register('color')}
              />
            </div>
          </CardBody>
        </Card>

        <Card>
          <CardBody className="space-y-4">
            <p className="text-sm font-semibold text-foreground">{t('pets.microchip')}</p>
            <TextField
              label={t('pets.microchipNumber')}
              placeholder={t('pets.microchipPlaceholder')}
              {...register('microchip')}
            />
          </CardBody>
        </Card>

        <div className="flex justify-end gap-3">
          <Button type="button" variant="outline" onClick={() => navigate(-1)}>
            {t('common.cancel')}
          </Button>
          <Button type="submit" loading={isSubmitting}>
            {isEdit ? t('common.save') : t('pets.new')}
          </Button>
        </div>

        {isEdit && !isVetView && (
          <div className="border-t border-border pt-6">
            <Button type="button" variant="destructive" onClick={() => setDeleteOpen(true)}>
              {t('pets.delete')}
            </Button>
          </div>
        )}
      </form>

      <Dialog
        open={deleteOpen}
        onClose={() => (deleting ? undefined : setDeleteOpen(false))}
        title={t('pets.delete')}
        description={t('pets.deleteDesc', { name: existing?.name ?? t('pets.thisPet') })}
        footer={
          <>
            <Button variant="outline" disabled={deleting} onClick={() => setDeleteOpen(false)}>
              {t('common.cancel')}
            </Button>
            <Button variant="destructive" loading={deleting} onClick={() => void onDelete()}>
              {t('common.delete')}
            </Button>
          </>
        }
      />
    </div>
  );
}
