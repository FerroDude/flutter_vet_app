import { useEffect, useState } from 'react';
import { toast } from 'sonner';
import {
  type Medication,
  type TimeOfDay,
  MedicationFrequency,
  frequencyDisplay,
} from '@vetplus/shared';
import {
  createMedication,
  updateMedicationFields,
  type MedicationInput,
} from '@/lib/medicationService';
import { Dialog } from '@/components/ui/Dialog';
import { Button } from '@/components/ui/Button';
import { TextField } from '@/components/ui/TextField';
import { Textarea } from '@/components/ui/Textarea';
import { Select } from '@/components/ui/Select';
import { TimeField } from '@/components/ui/TimeField';

const FREQS: MedicationFrequency[] = [
  MedicationFrequency.once,
  MedicationFrequency.daily,
  MedicationFrequency.twiceDaily,
  MedicationFrequency.threeTimesDaily,
  MedicationFrequency.weekly,
  MedicationFrequency.asNeeded,
];

const DEFAULT_TIMES: TimeOfDay[] = [
  { hour: 8, minute: 0 },
  { hour: 20, minute: 0 },
  { hour: 14, minute: 0 },
];

function timeCount(freq: MedicationFrequency): number {
  switch (freq) {
    case MedicationFrequency.twiceDaily:
      return 2;
    case MedicationFrequency.threeTimesDaily:
      return 3;
    case MedicationFrequency.asNeeded:
      return 0;
    default:
      return 1;
  }
}

function timeToInput(t: TimeOfDay): string {
  return `${`${t.hour}`.padStart(2, '0')}:${`${t.minute}`.padStart(2, '0')}`;
}

function inputToTime(v: string): TimeOfDay {
  const [h, m] = v.split(':').map(Number);
  return { hour: h || 0, minute: m || 0 };
}

function dateToInput(d: Date): string {
  return `${d.getFullYear()}-${`${d.getMonth() + 1}`.padStart(2, '0')}-${`${d.getDate()}`.padStart(2, '0')}`;
}

interface Props {
  open: boolean;
  onClose: () => void;
  uid: string;
  petId: string;
  existing?: Medication | null;
}

export function MedicationFormDialog({ open, onClose, uid, petId, existing }: Props) {
  const isEdit = Boolean(existing);
  const [name, setName] = useState('');
  const [dosage, setDosage] = useState('');
  const [frequency, setFrequency] = useState<MedicationFrequency>(MedicationFrequency.daily);
  const [times, setTimes] = useState<TimeOfDay[]>([{ hour: 8, minute: 0 }]);
  const [startDate, setStartDate] = useState(dateToInput(new Date()));
  const [ongoing, setOngoing] = useState(true);
  const [totalDays, setTotalDays] = useState('7');
  const [instructions, setInstructions] = useState('');
  const [trackDoses, setTrackDoses] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!open) return;
    if (existing) {
      setName(existing.name);
      setDosage(existing.dosage);
      setFrequency(existing.frequency);
      setTimes(existing.doseTimes.length ? existing.doseTimes : [{ hour: 8, minute: 0 }]);
      setStartDate(dateToInput(existing.startDate));
      setOngoing(existing.totalDays == null);
      setTotalDays(existing.totalDays != null ? String(existing.totalDays) : '7');
      setInstructions(existing.instructions ?? '');
      setTrackDoses(existing.trackDoses);
    } else {
      setName('');
      setDosage('');
      setFrequency(MedicationFrequency.daily);
      setTimes([{ hour: 8, minute: 0 }]);
      setStartDate(dateToInput(new Date()));
      setOngoing(true);
      setTotalDays('7');
      setInstructions('');
      setTrackDoses(true);
    }
  }, [open, existing]);

  // Keep the number of dose-time inputs in sync with the frequency.
  useEffect(() => {
    const count = timeCount(frequency);
    setTimes((prev) => {
      const next: TimeOfDay[] = [];
      for (let i = 0; i < count; i++) next.push(prev[i] ?? DEFAULT_TIMES[i] ?? { hour: 8, minute: 0 });
      return next;
    });
  }, [frequency]);

  const submit = async () => {
    if (!name.trim()) {
      toast.error('Indique o nome da medicação');
      return;
    }
    const [y, mo, d] = startDate.split('-').map(Number);
    const input: MedicationInput = {
      name,
      dosage,
      instructions,
      frequency,
      doseTimes: times.length ? times : [{ hour: 8, minute: 0 }],
      startDate: new Date(y ?? 1970, (mo ?? 1) - 1, d ?? 1),
      totalDays: ongoing ? null : Math.max(1, parseInt(totalDays, 10) || 1),
      trackDoses,
    };
    setSaving(true);
    try {
      if (isEdit && existing) {
        await updateMedicationFields(uid, petId, existing.id, input);
        toast.success('Medicação atualizada');
      } else {
        await createMedication(uid, petId, input);
        toast.success('Medicação adicionada');
      }
      onClose();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Não foi possível guardar a medicação');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title={isEdit ? 'Editar medicação' : 'Adicionar medicação'}
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
        <TextField label="Nome" value={name} onChange={(e) => setName(e.target.value)} />
        <div className="grid gap-4 sm:grid-cols-2">
          <TextField
            label="Dose"
            placeholder="ex. 1 comprimido, 5 ml"
            value={dosage}
            onChange={(e) => setDosage(e.target.value)}
          />
          <Select
            label="Frequência"
            value={frequency}
            onChange={(e) => setFrequency(Number(e.target.value) as MedicationFrequency)}
          >
            {FREQS.map((f) => (
              <option key={f} value={f}>
                {frequencyDisplay(f)}
              </option>
            ))}
          </Select>
        </div>

        {times.length > 0 && (
          <div className="flex flex-col gap-1.5">
            <span className="text-sm font-medium text-foreground">Horas da dose</span>
            <div className="flex flex-wrap gap-2">
              {times.map((t, i) => (
                <TimeField
                  key={i}
                  minuteStep={5}
                  value={timeToInput(t)}
                  onChange={(v) =>
                    setTimes((prev) => prev.map((p, j) => (j === i ? inputToTime(v) : p)))
                  }
                />
              ))}
            </div>
          </div>
        )}

        <div className="grid gap-4 sm:grid-cols-2">
          <TextField
            label="Data de início"
            type="date"
            value={startDate}
            onChange={(e) => setStartDate(e.target.value)}
          />
          <div className="flex flex-col gap-1.5">
            <span className="text-sm font-medium text-foreground">Duração</span>
            <div className="flex h-11 items-center gap-2">
              <label className="inline-flex items-center gap-2 text-sm text-muted-foreground">
                <input
                  type="checkbox"
                  checked={ongoing}
                  onChange={(e) => setOngoing(e.target.checked)}
                  className="h-4 w-4 accent-[hsl(var(--primary))]"
                />
                Contínua
              </label>
              {!ongoing && (
                <input
                  type="number"
                  min={1}
                  value={totalDays}
                  onChange={(e) => setTotalDays(e.target.value)}
                  className="h-11 w-24 rounded-(--radius-md) border border-input bg-card px-3 text-sm text-foreground focus-visible:border-ring focus-visible:outline-1 focus-visible:outline-offset-0 focus-visible:outline-ring"
                  aria-label="Dias no total"
                />
              )}
              {!ongoing && <span className="text-sm text-muted-foreground">dias</span>}
            </div>
          </div>
        </div>

        <Textarea
          label="Instruções (opcional)"
          value={instructions}
          onChange={(e) => setInstructions(e.target.value)}
          placeholder="Com comida, etc."
        />

        <label className="inline-flex items-center gap-2 text-sm text-muted-foreground">
          <input
            type="checkbox"
            checked={trackDoses}
            onChange={(e) => setTrackDoses(e.target.checked)}
            className="h-4 w-4 accent-[hsl(var(--primary))]"
          />
          Registar doses (marcar cada toma)
        </label>
      </div>
    </Dialog>
  );
}
