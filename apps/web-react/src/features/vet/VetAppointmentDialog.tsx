import { useEffect, useMemo, useState } from 'react';
import { toast } from 'sonner';
import { useCollection } from '@/lib/useFirestore';
import { useClients } from '@/lib/useClients';
import { clientLabel } from '@/lib/clientService';
import { errorMessage } from '@/lib/format';
import { petsQuery, mapPet, type Pet } from '@/lib/petService';
import { appointmentTitle, saveVetAppointment, type AppointmentEvent } from '@/lib/eventService';
import { toLocalInput } from '@/features/calendar/EventFormDialog';
import { Dialog } from '@/components/ui/Dialog';
import { Button } from '@/components/ui/Button';
import { Select } from '@/components/ui/Select';
import { TextField } from '@/components/ui/TextField';
import { DateTimeField } from '@/components/ui/TimeField';
import { Textarea } from '@/components/ui/Textarea';
import { t } from '@/i18n';

function defaultStart(day: Date): Date {
  const d = new Date(day);
  const now = new Date();
  if (d.toDateString() === now.toDateString()) {
    d.setHours(now.getHours() + 1, 0, 0, 0);
  } else {
    d.setHours(9, 0, 0, 0);
  }
  return d;
}

interface Props {
  open: boolean;
  onClose: () => void;
  vetId: string;
  vetName: string;
  defaultDay: Date;
  /** Edit this appointment. The client can't be changed when editing. */
  existing?: AppointmentEvent | null;
  /** Preselect a client / pet (e.g. opened from the client or pet page). */
  presetClientId?: string;
  presetPetId?: string;
  /** Other appointments, to warn about clashes. */
  others?: AppointmentEvent[];
}

export function VetAppointmentDialog({
  open,
  onClose,
  vetId,
  vetName,
  defaultDay,
  existing,
  presetClientId,
  presetPetId,
  others = [],
}: Props) {
  const isEdit = Boolean(existing);

  const { clients } = useClients(vetId);

  const [clientId, setClientId] = useState('');
  const [petId, setPetId] = useState('');
  const [when, setWhen] = useState('');
  const [title, setTitle] = useState('');
  const [titleTouched, setTitleTouched] = useState(false);
  const [location, setLocation] = useState('');
  const [description, setDescription] = useState('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!open) return;
    if (existing) {
      setClientId(existing.userId);
      setPetId(existing.petId ?? '');
      setWhen(toLocalInput(existing.dateTime));
      setTitle(existing.title);
      setTitleTouched(true);
      setLocation(existing.location ?? '');
      setDescription(existing.description ?? '');
    } else {
      setClientId(presetClientId ?? '');
      setPetId(presetPetId ?? '');
      setWhen(toLocalInput(defaultStart(defaultDay)));
      setTitle('');
      setTitleTouched(false);
      setLocation('');
      setDescription('');
    }
  }, [open, existing, presetClientId, presetPetId, defaultDay]);

  const pq = useMemo(() => (clientId ? petsQuery(clientId) : null), [clientId]);
  const { data: pets } = useCollection<Pet>(pq, mapPet);
  const pet = pets.find((p) => p.id === petId) ?? null;
  const client = clients.find((c) => c.id === clientId) ?? null;

  // Pick the only pet automatically; drop a pet that isn't this client's.
  useEffect(() => {
    if (!clientId) return;
    if (petId && pets.length && !pets.some((p) => p.id === petId)) setPetId('');
    if (!petId && pets.length === 1 && pets[0]) setPetId(pets[0].id);
  }, [clientId, pets, petId]);

  const autoTitle = appointmentTitle(pet?.name);
  const effectiveTitle = titleTouched ? title : autoTitle;

  const dateTime = when ? new Date(when) : null;
  const clash =
    dateTime && !Number.isNaN(dateTime.getTime())
      ? others.find(
          (o) =>
            o.id !== existing?.id && Math.abs(o.dateTime.getTime() - dateTime.getTime()) < 30 * 60_000,
        )
      : undefined;

  const submit = async () => {
    if (!clientId) {
      toast.error(t('vetAppt.pickClient'));
      return;
    }
    if (!dateTime || Number.isNaN(dateTime.getTime())) {
      toast.error(t('vetAgenda.pickDateTime'));
      return;
    }
    setSaving(true);
    try {
      await saveVetAppointment({
        id: existing?.id ?? null,
        clientId,
        clientName: client ? clientLabel(client) : existing?.clientName || t('common.client'),
        petId: petId || null,
        petName: pet?.name ?? (petId ? existing?.petName ?? null : null),
        vetId,
        vetName,
        title: effectiveTitle.trim() || t('event.appointmentName'),
        description: description.trim(),
        location: location.trim() || null,
        dateTime,
        appointmentRequestId: existing?.appointmentRequestId ?? null,
      });
      toast.success(isEdit ? t('vetAppt.updated') : t('vetAppt.booked'));
      onClose();
    } catch (e) {
      toast.error(errorMessage(e, t('vetAppt.saveFailed')));
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog
      open={open}
      onClose={() => (saving ? undefined : onClose())}
      title={isEdit ? t('vetAgenda.editAppt') : t('vetAppt.new')}
      description={isEdit ? undefined : t('vetAppt.newDesc')}
      className="max-w-lg"
      footer={
        <>
          <Button variant="outline" disabled={saving} onClick={onClose}>
            {t('common.cancel')}
          </Button>
          <Button loading={saving} onClick={() => void submit()}>
            {isEdit ? t('common.save') : t('vetAppt.book')}
          </Button>
        </>
      }
    >
      <div className="space-y-4">
        <div className="grid gap-4 sm:grid-cols-2">
          <Select
            label={t('vetAppt.client')}
            value={clientId}
            disabled={isEdit}
            onChange={(e) => {
              setClientId(e.target.value);
              setPetId('');
            }}
          >
            <option value="">{t('vetAppt.choose')}</option>
            {isEdit && !client && existing && (
              <option value={existing.userId}>{existing.clientName || t('common.client')}</option>
            )}
            {clients.map((c) => (
              <option key={c.id} value={c.id}>
                {clientLabel(c)}
              </option>
            ))}
          </Select>
          <Select
            label={t('common.pet')}
            value={petId}
            disabled={!clientId}
            onChange={(e) => setPetId(e.target.value)}
          >
            <option value="">{clientId && pets.length === 0 ? t('vetAppt.noPets') : t('event.noPet')}</option>
            {pets.map((p) => (
              <option key={p.id} value={p.id}>
                {p.species ? `${p.name} (${p.species})` : p.name}
              </option>
            ))}
          </Select>
        </div>

        <DateTimeField
          label={t('appointment.dateTime')}
          value={when}
          onChange={setWhen}
          hint={
            clash
              ? t('vetAppt.clash', { name: clash.clientName || t('vetAppt.clashFallback') })
              : undefined
          }
        />

        <TextField
          label={t('event.title')}
          value={effectiveTitle}
          onChange={(e) => {
            setTitleTouched(true);
            setTitle(e.target.value);
          }}
        />

        <TextField
          label={t('vetAppt.location')}
          value={location}
          onChange={(e) => setLocation(e.target.value)}
          placeholder={t('vetAppt.locationPlaceholder')}
        />

        <Textarea
          label={t('vetAppt.notes')}
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder={t('vetAppt.notesPlaceholder')}
        />
      </div>
    </Dialog>
  );
}
