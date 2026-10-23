import { useEffect, useState } from 'react';
import { toast } from 'sonner';
import { TimePreference } from '@vetplus/shared';
import { type Pet } from '@/lib/petService';
import { createRequest } from '@/lib/appointmentRequestService';
import { Dialog } from '@/components/ui/Dialog';
import { Button } from '@/components/ui/Button';
import { Select } from '@/components/ui/Select';
import { TextField } from '@/components/ui/TextField';
import { Textarea } from '@/components/ui/Textarea';

const TIME_PREFERENCES: { value: TimePreference; label: string }[] = [
  { value: TimePreference.anyTime, label: 'Qualquer hora' },
  { value: TimePreference.morning, label: 'Manhã (8h – 12h)' },
  { value: TimePreference.afternoon, label: 'Tarde (12h – 17h)' },
  { value: TimePreference.evening, label: 'Noite (17h – 20h)' },
];

function toDateInput(d: Date): string {
  const pad = (n: number) => `${n}`.padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function addDays(days: number): Date {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  d.setDate(d.getDate() + days);
  return d;
}

interface Props {
  open: boolean;
  onClose: () => void;
  vetId: string;
  petOwnerId: string;
  petOwnerName: string;
  pets: Pet[];
}

export function AppointmentRequestFormDialog({
  open,
  onClose,
  vetId,
  petOwnerId,
  petOwnerName,
  pets,
}: Props) {
  const [petId, setPetId] = useState('');
  const [start, setStart] = useState(() => toDateInput(addDays(1)));
  const [end, setEnd] = useState(() => toDateInput(addDays(7)));
  const [timePref, setTimePref] = useState<TimePreference>(TimePreference.anyTime);
  const [reason, setReason] = useState('');
  const [notes, setNotes] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (open) {
      setPetId(pets[0]?.id ?? '');
      setStart(toDateInput(addDays(1)));
      setEnd(toDateInput(addDays(7)));
      setTimePref(TimePreference.anyTime);
      setReason('');
      setNotes('');
      setError(null);
    }
  }, [open, pets]);

  const submit = async () => {
    const pet = pets.find((p) => p.id === petId);
    if (!pet) {
      setError('Escolha um animal.');
      return;
    }
    if (!reason.trim()) {
      setError('Indique o motivo da consulta.');
      return;
    }
    const startDate = start ? new Date(`${start}T00:00:00`) : addDays(1);
    let endDate = end ? new Date(`${end}T00:00:00`) : startDate;
    if (endDate < startDate) endDate = startDate;

    setSaving(true);
    setError(null);
    try {
      await createRequest({
        vetId,
        petOwnerId,
        petOwnerName,
        petId: pet.id,
        petName: pet.name,
        petSpecies: pet.species ?? null,
        preferredDateStart: startDate,
        preferredDateEnd: endDate,
        timePreference: timePref,
        reason: reason.trim(),
        notes: notes.trim() ? notes.trim() : null,
      });
      toast.success('Pedido de marcação enviado');
      onClose();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Não foi possível enviar o pedido');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title="Pedir marcação"
      description="A veterinária revê o pedido e confirma a hora."
      footer={
        <>
          <Button variant="outline" onClick={onClose}>
            Cancelar
          </Button>
          <Button loading={saving} onClick={() => void submit()}>
            Enviar pedido
          </Button>
        </>
      }
    >
      <div className="space-y-4">
        {pets.length === 0 ? (
          <p className="text-sm text-muted-foreground">Adicione um animal antes de pedir uma marcação.</p>
        ) : (
          <Select label="Animal" value={petId} onChange={(e) => setPetId(e.target.value)}>
            {pets.map((p) => (
              <option key={p.id} value={p.id}>
                {p.species ? `${p.name} (${p.species})` : p.name}
              </option>
            ))}
          </Select>
        )}

        <div className="grid gap-4 sm:grid-cols-2">
          <TextField
            label="De"
            type="date"
            value={start}
            onChange={(e) => setStart(e.target.value)}
          />
          <TextField
            label="Até"
            type="date"
            min={start}
            value={end}
            onChange={(e) => setEnd(e.target.value)}
          />
        </div>

        <Select
          label="Altura do dia"
          value={timePref}
          onChange={(e) => setTimePref(Number(e.target.value) as TimePreference)}
        >
          {TIME_PREFERENCES.map((t) => (
            <option key={t.value} value={t.value}>
              {t.label}
            </option>
          ))}
        </Select>

        <TextField
          label="Motivo"
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          placeholder="Consulta anual, vacina, pele…"
        />

        <Textarea
          label="Notas (opcional)"
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          placeholder="Mais informação para a veterinária…"
        />

        {error && <p className="text-sm font-medium text-destructive">{error}</p>}
      </div>
    </Dialog>
  );
}
