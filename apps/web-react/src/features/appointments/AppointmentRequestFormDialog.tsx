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
  { value: TimePreference.anyTime, label: 'Any time' },
  { value: TimePreference.morning, label: 'Morning (8am - 12pm)' },
  { value: TimePreference.afternoon, label: 'Afternoon (12pm - 5pm)' },
  { value: TimePreference.evening, label: 'Evening (5pm - 8pm)' },
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
  clinicId: string;
  petOwnerId: string;
  petOwnerName: string;
  pets: Pet[];
}

export function AppointmentRequestFormDialog({
  open,
  onClose,
  clinicId,
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
      setError('Please select a pet.');
      return;
    }
    if (!reason.trim()) {
      setError('Please enter a reason for the appointment.');
      return;
    }
    const startDate = start ? new Date(`${start}T00:00:00`) : addDays(1);
    let endDate = end ? new Date(`${end}T00:00:00`) : startDate;
    if (endDate < startDate) endDate = startDate;

    setSaving(true);
    setError(null);
    try {
      await createRequest({
        clinicId,
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
      toast.success('Appointment request submitted');
      onClose();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not submit request');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title="Request an appointment"
      description="Your clinic will review and confirm a time."
      footer={
        <>
          <Button variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button loading={saving} onClick={() => void submit()}>
            Submit request
          </Button>
        </>
      }
    >
      <div className="space-y-4">
        {pets.length === 0 ? (
          <p className="text-sm text-muted-foreground">Add a pet first to request an appointment.</p>
        ) : (
          <Select label="Pet" value={petId} onChange={(e) => setPetId(e.target.value)}>
            {pets.map((p) => (
              <option key={p.id} value={p.id}>
                {p.species ? `${p.name} (${p.species})` : p.name}
              </option>
            ))}
          </Select>
        )}

        <div className="grid gap-4 sm:grid-cols-2">
          <TextField
            label="Preferred from"
            type="date"
            value={start}
            onChange={(e) => setStart(e.target.value)}
          />
          <TextField
            label="Preferred to"
            type="date"
            min={start}
            value={end}
            onChange={(e) => setEnd(e.target.value)}
          />
        </div>

        <Select
          label="Preferred time"
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
          label="Reason for visit"
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          placeholder="e.g., Annual checkup, vaccination, skin issue…"
        />

        <Textarea
          label="Additional notes (optional)"
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          placeholder="Any additional information for the clinic…"
        />

        {error && <p className="text-sm font-medium text-destructive">{error}</p>}
      </div>
    </Dialog>
  );
}
