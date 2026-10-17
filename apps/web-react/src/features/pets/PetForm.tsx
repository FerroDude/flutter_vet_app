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
  petDoc,
  mapPet,
  type PetFields,
  type Pet,
} from '@/lib/petService';
import { useDoc } from '@/lib/useFirestore';
import { TextField } from '@/components/ui/TextField';
import { Textarea } from '@/components/ui/Textarea';
import { Select } from '@/components/ui/Select';
import { Button } from '@/components/ui/Button';
import { Card, CardBody } from '@/components/ui/Card';
import { PageSpinner } from '@/components/Spinner';

const schema = z.object({
  name: z.string().trim().min(1, 'Please enter a name'),
  species: z.string().trim().min(1, 'Please enter the species'),
  breed: z.string().trim().min(1, 'Please enter the breed'),
  gender: z.enum(['Male', 'Female', 'Unknown']),
  dateOfBirth: z.string().optional(),
  weight: z.string().optional(),
  color: z.string().optional(),
  microchip: z.string().optional(),
  veterinarian: z.string().optional(),
  medicalNotes: z.string().optional(),
  emergencyContact: z.string().optional(),
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
  const { petId } = useParams<{ petId: string }>();
  const isEdit = Boolean(petId);
  const navigate = useNavigate();
  const { firebaseUser } = useAuth();
  const uid = firebaseUser?.uid ?? '';

  const ref = useMemo(
    () => (isEdit && uid ? petDoc(uid, petId!) : null),
    [isEdit, uid, petId],
  );
  const { data: existing, loading } = useDoc<Pet>(ref, mapPet);

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { gender: 'Unknown' },
  });

  const [hydrated, setHydrated] = useState(false);
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
        veterinarian: existing.veterinarian,
        medicalNotes: existing.medicalNotes,
        emergencyContact: existing.emergencyContact,
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
      veterinarian: values.veterinarian ?? '',
      medicalNotes: values.medicalNotes ?? '',
      emergencyContact: values.emergencyContact ?? '',
    };
    try {
      if (isEdit) {
        await updatePet(uid, petId!, fields);
        toast.success('Pet updated');
        navigate(`/pets/${petId}`);
      } else {
        const newId = await addPet(uid, fields);
        toast.success('Pet added');
        navigate(`/pets/${newId}`);
      }
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not save pet');
    }
  };

  return (
    <div className="mx-auto max-w-2xl">
      <button
        type="button"
        onClick={() => navigate(-1)}
        className="mb-4 inline-flex items-center gap-1.5 text-sm font-medium text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft size={16} /> Back
      </button>
      <h1 className="mb-6 font-display text-3xl font-bold text-foreground">
        {isEdit ? 'Edit pet' : 'Add a pet'}
      </h1>

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
        <Card>
          <CardBody className="space-y-4">
            <p className="text-sm font-semibold text-foreground">Basic information</p>
            <TextField label="Name" error={errors.name?.message} {...register('name')} />
            <div className="grid gap-4 sm:grid-cols-2">
              <TextField
                label="Species"
                placeholder="Dog, Cat, Bird…"
                error={errors.species?.message}
                {...register('species')}
              />
              <TextField
                label="Breed"
                error={errors.breed?.message}
                {...register('breed')}
              />
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <Select label="Gender" error={errors.gender?.message} {...register('gender')}>
                <option value="Male">Male</option>
                <option value="Female">Female</option>
                <option value="Unknown">Unknown</option>
              </Select>
              <TextField
                label="Date of birth"
                type="date"
                error={errors.dateOfBirth?.message}
                {...register('dateOfBirth')}
              />
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <TextField
                label="Weight"
                placeholder="e.g. 15 kg"
                {...register('weight')}
              />
              <TextField
                label="Color / markings"
                placeholder="Brown, white spots…"
                {...register('color')}
              />
            </div>
          </CardBody>
        </Card>

        <Card>
          <CardBody className="space-y-4">
            <p className="text-sm font-semibold text-foreground">Medical information</p>
            <TextField
              label="Microchip number"
              placeholder="ID number if microchipped"
              {...register('microchip')}
            />
            <TextField
              label="Veterinarian"
              placeholder="Primary vet name or clinic"
              {...register('veterinarian')}
            />
            <Textarea
              label="Medical notes"
              placeholder="Allergies, conditions, medications"
              {...register('medicalNotes')}
            />
            <TextField
              label="Emergency contact"
              placeholder="Name and phone number"
              {...register('emergencyContact')}
            />
          </CardBody>
        </Card>

        <div className="flex justify-end gap-3">
          <Button type="button" variant="outline" onClick={() => navigate(-1)}>
            Cancel
          </Button>
          <Button type="submit" loading={isSubmitting}>
            {isEdit ? 'Save changes' : 'Add pet'}
          </Button>
        </div>
      </form>
    </div>
  );
}
