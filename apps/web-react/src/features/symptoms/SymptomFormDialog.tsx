import { useState } from 'react';
import { toast } from 'sonner';
import { SYMPTOM_LABELS, SYMPTOM_TYPES, type SymptomType } from '@vetplus/shared';
import { addSymptom } from '@/lib/petService';
import { Dialog } from '@/components/ui/Dialog';
import { Button } from '@/components/ui/Button';
import { Select } from '@/components/ui/Select';
import { Textarea } from '@/components/ui/Textarea';

function toLocalInput(d: Date): string {
  const pad = (n: number) => `${n}`.padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

interface Props {
  open: boolean;
  onClose: () => void;
  uid: string;
  petId: string;
  petName?: string;
  /** Default date for the "when" field. */
  defaultDate?: Date;
}

export function SymptomFormDialog({ open, onClose, uid, petId, petName, defaultDate }: Props) {
  const [type, setType] = useState<SymptomType>('vomiting');
  const [when, setWhen] = useState(() => toLocalInput(defaultDate ?? new Date()));
  const [note, setNote] = useState('');
  const [saving, setSaving] = useState(false);

  const submit = async () => {
    if (!petId) return;
    const at = when ? new Date(when) : new Date();
    setSaving(true);
    try {
      await addSymptom(uid, petId, type, at, note);
      toast.success('Sintoma registado');
      setNote('');
      onClose();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Não foi possível registar o sintoma');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title="Registar sintoma"
      description={petName ? `De ${petName}` : undefined}
      footer={
        <>
          <Button variant="outline" onClick={onClose}>
            Cancelar
          </Button>
          <Button loading={saving} onClick={() => void submit()}>
            Guardar
          </Button>
        </>
      }
    >
      <div className="space-y-4">
        <Select label="Sintoma" value={type} onChange={(e) => setType(e.target.value as SymptomType)}>
          {SYMPTOM_TYPES.map((s) => (
            <option key={s} value={s}>
              {SYMPTOM_LABELS[s]}
            </option>
          ))}
        </Select>
        <div className="flex flex-col gap-1.5">
          <label htmlFor="symptom-when" className="text-sm font-medium text-foreground">
            Quando
          </label>
          <input
            id="symptom-when"
            type="datetime-local"
            value={when}
            onChange={(e) => setWhen(e.target.value)}
            className="h-11 w-full rounded-(--radius-md) border border-input bg-card px-3.5 text-sm text-foreground focus-visible:border-ring focus-visible:outline-1 focus-visible:outline-offset-0 focus-visible:outline-ring"
          />
        </div>
        <Textarea
          label="Nota (opcional)"
          value={note}
          onChange={(e) => setNote(e.target.value)}
          placeholder="Algo a registar…"
        />
      </div>
    </Dialog>
  );
}
