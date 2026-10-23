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
import { PetPhotoPicker } from './PetPhotoPicker';
import { TextField } from '@/components/ui/TextField';
import { Select } from '@/components/ui/Select';
import { Button } from '@/components/ui/Button';
import { Card, CardBody } from '@/components/ui/Card';
import { Dialog } from '@/components/ui/Dialog';
import { PageSpinner } from '@/components/Spinner';

const schema = z.object({
  name: z.string().trim().min(1, 'Indique o nome'),
  species: z.string().trim().min(1, 'Indique a espécie'),
  breed: z.string().trim().min(1, 'Indique a raça'),
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
  const [photoFile, setPhotoFile] = useState<File | null>(null);
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
      if (photoFile) {
        try {
          await uploadPetPhoto(uid, id, photoFile);
        } catch (e) {
          photoError = errorMessage(e);
        }
      } else if (removePhoto) {
        await removePetPhoto(uid, id);
      }

      toast.success(isEdit ? 'Animal atualizado' : 'Animal adicionado');
      if (photoError) toast.error(`O animal foi guardado, mas a foto falhou: ${photoError}`);
      navigate(`${petBase}/${id}`);
    } catch (e) {
      toast.error(errorMessage(e));
    }
  };

  const onDelete = async () => {
    if (!uid || !petId) return;
    setDeleting(true);
    try {
      await deletePet(uid, petId);
      toast.success('Animal apagado');
      navigate('/pets');
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Não foi possível apagar o animal');
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
        <ArrowLeft size={16} /> Voltar
      </button>
      <h1 className="mb-6 font-display text-3xl font-bold text-foreground">
        {isEdit ? 'Editar animal' : 'Adicionar animal'}
      </h1>

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
        {!isVetView && (
          <Card>
            <CardBody className="space-y-4">
              <p className="text-sm font-semibold text-foreground">Foto</p>
              <PetPhotoPicker
                photoUrl={removePhoto ? null : (existing?.photoUrl ?? null)}
                file={photoFile}
                name={watch('name') || existing?.name || ''}
                disabled={isSubmitting}
                onPick={(f) => {
                  setPhotoFile(f);
                  setRemovePhoto(false);
                }}
                onRemove={() => {
                  setPhotoFile(null);
                  if (existing?.photoUrl) setRemovePhoto(true);
                }}
              />
            </CardBody>
          </Card>
        )}

        <Card>
          <CardBody className="space-y-4">
            <p className="text-sm font-semibold text-foreground">Dados</p>
            <TextField label="Nome" error={errors.name?.message} {...register('name')} />
            <div className="grid gap-4 sm:grid-cols-2">
              <TextField
                label="Espécie"
                placeholder="Cão, gato, ave…"
                error={errors.species?.message}
                {...register('species')}
              />
              <TextField
                label="Raça"
                error={errors.breed?.message}
                {...register('breed')}
              />
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <Select label="Sexo" error={errors.gender?.message} {...register('gender')}>
                <option value="Male">Macho</option>
                <option value="Female">Fêmea</option>
                <option value="Unknown">Desconhecido</option>
              </Select>
              <TextField
                label="Data de nascimento"
                type="date"
                error={errors.dateOfBirth?.message}
                {...register('dateOfBirth')}
              />
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <TextField
                label="Peso"
                placeholder="ex. 15 kg"
                {...register('weight')}
              />
              <TextField
                label="Cor / marcas"
                placeholder="Castanho, manchas brancas…"
                {...register('color')}
              />
            </div>
          </CardBody>
        </Card>

        <Card>
          <CardBody className="space-y-4">
            <p className="text-sm font-semibold text-foreground">Microchip</p>
            <TextField
              label="Número de microchip"
              placeholder="Número, se tiver microchip"
              {...register('microchip')}
            />
          </CardBody>
        </Card>

        <div className="flex justify-end gap-3">
          <Button type="button" variant="outline" onClick={() => navigate(-1)}>
            Cancelar
          </Button>
          <Button type="submit" loading={isSubmitting}>
            {isEdit ? 'Guardar' : 'Adicionar animal'}
          </Button>
        </div>

        {isEdit && !isVetView && (
          <div className="border-t border-border pt-6">
            <Button type="button" variant="destructive" onClick={() => setDeleteOpen(true)}>
              Apagar animal
            </Button>
          </div>
        )}
      </form>

      <Dialog
        open={deleteOpen}
        onClose={() => (deleting ? undefined : setDeleteOpen(false))}
        title="Apagar animal"
        description={`Apagar ${existing?.name ?? 'este animal'}? Não dá para desfazer.`}
        footer={
          <>
            <Button variant="outline" disabled={deleting} onClick={() => setDeleteOpen(false)}>
              Cancelar
            </Button>
            <Button variant="destructive" loading={deleting} onClick={() => void onDelete()}>
              Apagar
            </Button>
          </>
        }
      />
    </div>
  );
}
