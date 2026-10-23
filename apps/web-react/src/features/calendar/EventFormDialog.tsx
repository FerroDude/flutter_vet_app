import { useEffect, useState } from 'react';
import { toast } from 'sonner';
import { EventType } from '@vetplus/shared';
import {
  createEvent,
  updateEvent,
  type CalendarEvent,
  type NewEvent,
} from '@/lib/eventService';
import { type Pet } from '@/lib/petService';
import { Dialog } from '@/components/ui/Dialog';
import { Button } from '@/components/ui/Button';
import { TextField } from '@/components/ui/TextField';
import { Textarea } from '@/components/ui/Textarea';
import { Select } from '@/components/ui/Select';
import { cn } from '@/lib/cn';

type FormType = EventType.appointment | EventType.note;

interface Props {
  open: boolean;
  onClose: () => void;
  uid: string;
  pets: Pet[];
  defaultDate: Date;
  existing?: CalendarEvent | null;
  /** Force the appointment type and hide the type switch (calendar add flow). */
  lockToAppointment?: boolean;
  /** Preselect a pet (calendar add flow after pet picker). */
  presetPetId?: string;
}

function toLocalInput(d: Date): string {
  const pad = (n: number) => `${n}`.padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export function EventFormDialog({
  open,
  onClose,
  uid,
  pets,
  defaultDate,
  existing,
  lockToAppointment,
  presetPetId,
}: Props) {
  const isEdit = Boolean(existing);
  const [type, setType] = useState<FormType>(EventType.appointment);
  const [title, setTitle] = useState('');
  const [when, setWhen] = useState(toLocalInput(defaultDate));
  const [petId, setPetId] = useState('');
  const [description, setDescription] = useState('');
  // appointment
  const [location, setLocation] = useState('');
  const [vetName, setVetName] = useState('');
  // note
  const [category, setCategory] = useState('');
  const [priority, setPriority] = useState('3');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!open) return;
    if (existing && existing.type !== EventType.medication) {
      setType(existing.type);
      setTitle(existing.title);
      setWhen(toLocalInput(existing.dateTime));
      setPetId(existing.petId ?? '');
      setDescription(existing.description);
      if (existing.type === EventType.appointment) {
        setLocation(existing.location ?? '');
        setVetName(existing.vetName ?? '');
      } else if (existing.type === EventType.note) {
        setCategory(existing.category ?? '');
        setPriority(String(existing.priority));
      }
    } else {
      setType(EventType.appointment);
      setTitle('');
      setWhen(toLocalInput(defaultDate));
      setPetId(presetPetId ?? '');
      setDescription('');
      setLocation('');
      setVetName('');
      setCategory('');
      setPriority('3');
    }
  }, [open, existing, defaultDate, presetPetId]);

  const submit = async () => {
    if (!title.trim()) {
      toast.error('Indique um título');
      return;
    }
    const now = new Date();
    const dateTime = when ? new Date(when) : defaultDate;
    const base = {
      title: title.trim(),
      description: description.trim(),
      dateTime,
      petId: petId || null,
      userId: uid,
      seriesId: null,
      isRecurring: false,
      recurrencePattern: null,
      recurrenceInterval: null,
      endDate: null,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    };

    let event: NewEvent;
    if (type === EventType.appointment) {
      event = {
        ...base,
        type: EventType.appointment,
        vetName: vetName.trim() || null,
        location: location.trim() || null,
        appointmentType: null,
        isConfirmed: false,
        contactInfo: null,
      };
    } else {
      event = {
        ...base,
        type: EventType.note,
        category: category.trim() || null,
        priority: parseInt(priority, 10) || 3,
        isCompleted: existing?.type === EventType.note ? existing.isCompleted : false,
        tags: null,
        reminderDateTime: null,
      };
    }

    setSaving(true);
    try {
      if (isEdit && existing) {
        await updateEvent(uid, { ...event, id: existing.id } as CalendarEvent);
        toast.success('Consulta atualizada');
      } else {
        await createEvent(uid, event);
        toast.success('Consulta adicionada');
      }
      onClose();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Não foi possível guardar');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title={isEdit ? 'Editar consulta' : 'Adicionar consulta'}
      className="max-w-lg"
      footer={
        <>
          <Button variant="outline" onClick={onClose}>
            Cancelar
          </Button>
          <Button loading={saving} onClick={() => void submit()}>
            {isEdit ? 'Guardar' : 'Adicionar'}
          </Button>
        </>
      }
    >
      <div className="space-y-4">
        {!isEdit && !lockToAppointment && (
          <div className="inline-flex rounded-(--radius-md) border border-border p-1">
            <TypeTab active={type === EventType.appointment} onClick={() => setType(EventType.appointment)}>
              Consulta
            </TypeTab>
            <TypeTab active={type === EventType.note} onClick={() => setType(EventType.note)}>
              Nota
            </TypeTab>
          </div>
        )}

        <TextField label="Título" value={title} onChange={(e) => setTitle(e.target.value)} />

        <div className="grid gap-4 sm:grid-cols-2">
          <div className="flex flex-col gap-1.5">
            <label htmlFor="event-when" className="text-sm font-medium text-foreground">
              Data e hora
            </label>
            <input
              id="event-when"
              type="datetime-local"
              value={when}
              onChange={(e) => setWhen(e.target.value)}
              className="h-11 w-full rounded-(--radius-md) border border-input bg-card px-3.5 text-sm text-foreground focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring"
            />
          </div>
          <Select label="Animal (opcional)" value={petId} onChange={(e) => setPetId(e.target.value)}>
            <option value="">Sem animal</option>
            {pets.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
          </Select>
        </div>

        {type === EventType.appointment ? (
          <div className="grid gap-4 sm:grid-cols-2">
            <TextField label="Local" value={location} onChange={(e) => setLocation(e.target.value)} />
            <TextField label="Veterinária" value={vetName} onChange={(e) => setVetName(e.target.value)} />
          </div>
        ) : (
          <div className="grid gap-4 sm:grid-cols-2">
            <TextField label="Categoria" value={category} onChange={(e) => setCategory(e.target.value)} />
            <Select label="Prioridade" value={priority} onChange={(e) => setPriority(e.target.value)}>
              <option value="1">Mínima</option>
              <option value="2">Baixa</option>
              <option value="3">Média</option>
              <option value="4">Alta</option>
              <option value="5">Máxima</option>
            </Select>
          </div>
        )}

        <Textarea
          label="Descrição (opcional)"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
        />
      </div>
    </Dialog>
  );
}

function TypeTab({
  active,
  onClick,
  children,
}: {
  active: boolean;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        'rounded-(--radius-sm) px-4 py-1.5 text-sm font-medium transition-colors',
        active ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:text-foreground',
      )}
    >
      {children}
    </button>
  );
}
