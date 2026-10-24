import { useEffect, useState } from 'react';
import { toast } from 'sonner';
import { TimePreference } from '@vetplus/shared';
import { type Pet } from '@/lib/petService';
import { createRequest } from '@/lib/appointmentRequestService';
import { timePreferenceText } from '@/lib/format';
import { Dialog } from '@/components/ui/Dialog';
import { Button } from '@/components/ui/Button';
import { Select } from '@/components/ui/Select';
import { TextField } from '@/components/ui/TextField';
import { Textarea } from '@/components/ui/Textarea';
import { t } from '@/i18n';

const TIME_PREFERENCES = [
  TimePreference.anyTime,
  TimePreference.morning,
  TimePreference.afternoon,
  TimePreference.evening,
].map((value) => ({ value, label: timePreferenceText(value) }));

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

export function RequestFormDialog({
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
      setError(t('requests.pickPet'));
      return;
    }
    if (!reason.trim()) {
      setError(t('requests.reasonRequired'));
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
      toast.success(t('requests.sent'));
      onClose();
    } catch (e) {
      setError(e instanceof Error ? e.message : t('requests.sendFailed'));
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title={t('requests.form.title')}
      footer={
        <>
          <Button variant="outline" onClick={onClose}>
            {t('common.cancel')}
          </Button>
          <Button loading={saving} onClick={() => void submit()}>
            {t('requests.send')}
          </Button>
        </>
      }
    >
      <div className="space-y-4">
        {pets.length === 0 ? (
          <p className="text-sm text-muted-foreground">{t('requests.noPets')}</p>
        ) : (
          <Select label={t('common.pet')} value={petId} onChange={(e) => setPetId(e.target.value)}>
            {pets.map((p) => (
              <option key={p.id} value={p.id}>
                {p.species ? `${p.name} (${p.species})` : p.name}
              </option>
            ))}
          </Select>
        )}

        <div className="grid gap-4 sm:grid-cols-2">
          <TextField
            label={t('requests.from')}
            type="date"
            value={start}
            onChange={(e) => setStart(e.target.value)}
          />
          <TextField
            label={t('requests.until')}
            type="date"
            min={start}
            value={end}
            onChange={(e) => setEnd(e.target.value)}
          />
        </div>

        <Select
          label={t('requests.timeOfDay')}
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
          label={t('requests.reason')}
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          placeholder={t('requests.reasonPlaceholder')}
        />

        <Textarea
          label={t('requests.notes')}
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          placeholder={t('requests.notesPlaceholder')}
        />

        {error && <p className="text-sm font-medium text-destructive">{error}</p>}
      </div>
    </Dialog>
  );
}
