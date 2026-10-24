import { useState } from 'react';
import { toast } from 'sonner';
import { SYMPTOM_LABELS, SYMPTOM_TYPES, type SymptomType } from '@vetplus/shared';
import { addSymptom } from '@/lib/petService';
import { Dialog } from '@/components/ui/Dialog';
import { Button } from '@/components/ui/Button';
import { Select } from '@/components/ui/Select';
import { Textarea } from '@/components/ui/Textarea';
import { DateTimeField } from '@/components/ui/TimeField';

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
        <DateTimeField label="Quando" value={when} onChange={setWhen} />
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
