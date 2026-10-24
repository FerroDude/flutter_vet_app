import { useEffect, useState } from 'react';
import { toast } from 'sonner';
import { EventType } from '@vetplus/shared';
import { createEvent, updateEvent, type CalendarEvent, type NewEvent } from '@/lib/eventService';
import { type Pet } from '@/lib/petService';
import { errorMessage } from '@/lib/format';
import { Dialog } from '@/components/ui/Dialog';
import { Button } from '@/components/ui/Button';
import { TextField } from '@/components/ui/TextField';
import { Textarea } from '@/components/ui/Textarea';
import { Select } from '@/components/ui/Select';
import { DateTimeField } from '@/components/ui/TimeField';

export function toLocalInput(d: Date): string {
  const p = (n: number) => `${n}`.padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
}

/**
 * Client's own calendar entries. New entries are reminders (notes); editing
 * keeps the original type, and appointments also show the location.
 */
export function EventFormDialog({
  open,
  onClose,
  uid,
  pets,
  defaultDate,
  existing,
  presetPetId,
}: {
  open: boolean;
  onClose: () => void;
  uid: string;
  pets: Pet[];
  defaultDate: Date;
  existing?: CalendarEvent | null;
  presetPetId?: string;
}) {
  const isAppointment = existing?.type === EventType.appointment;
  const [title, setTitle] = useState('');
  const [when, setWhen] = useState('');
  const [petId, setPetId] = useState('');
  const [description, setDescription] = useState('');
  const [location, setLocation] = useState('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!open) return;
    const start = new Date(defaultDate);
    if (!existing && start.getHours() === 0) start.setHours(9, 0, 0, 0);
    setTitle(existing?.title ?? '');
    setWhen(toLocalInput(existing?.dateTime ?? start));
    setPetId(existing?.petId ?? presetPetId ?? '');
    setDescription(existing?.description ?? '');
    setLocation(existing?.type === EventType.appointment ? (existing.location ?? '') : '');
  }, [open, existing, defaultDate, presetPetId]);

  const submit = async () => {
    if (!title.trim()) {
      toast.error('Indique um título.');
      return;
    }
    const now = new Date();
    const base = {
      title: title.trim(),
      description: description.trim(),
      dateTime: when ? new Date(when) : defaultDate,
      petId: petId || null,
      userId: uid,
      isRecurring: false,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    };
    const event: NewEvent =
      existing?.type === EventType.appointment
        ? { ...existing, ...base, location: location.trim() || null }
        : {
            ...base,
            type: EventType.note,
            priority: existing?.type === EventType.note ? existing.priority : 3,
            isCompleted: existing?.type === EventType.note ? existing.isCompleted : false,
          };

    setSaving(true);
    try {
      if (existing) await updateEvent(uid, { ...event, id: existing.id } as CalendarEvent);
      else await createEvent(uid, event);
      toast.success(existing ? 'Guardado' : 'Lembrete adicionado');
      onClose();
    } catch (e) {
      toast.error(errorMessage(e, 'Não foi possível guardar'));
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title={existing ? (isAppointment ? 'Editar consulta' : 'Editar lembrete') : 'Novo lembrete'}
      footer={
        <>
          <Button variant="outline" onClick={onClose}>
            Cancelar
          </Button>
          <Button loading={saving} onClick={() => void submit()}>
            {existing ? 'Guardar' : 'Adicionar'}
          </Button>
        </>
      }
    >
      <div className="space-y-4">
        <TextField
          label="Título"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="Banho, desparasitação, comprar ração…"
        />
        <div className="grid gap-4 sm:grid-cols-2">
          <DateTimeField label="Data e hora" value={when} onChange={setWhen} />
          <Select label="Animal (opcional)" value={petId} onChange={(e) => setPetId(e.target.value)}>
            <option value="">Sem animal</option>
            {pets.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
          </Select>
        </div>
        {isAppointment && (
          <TextField label="Local" value={location} onChange={(e) => setLocation(e.target.value)} />
        )}
        <Textarea label="Notas (opcional)" value={description} onChange={(e) => setDescription(e.target.value)} />
      </div>
    </Dialog>
  );
}
