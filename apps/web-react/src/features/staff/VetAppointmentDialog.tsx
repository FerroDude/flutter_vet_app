import { useEffect, useMemo, useState } from 'react';
import { toast } from 'sonner';
import { type UserProfile } from '@vetplus/shared';
import { useCollection } from '@/lib/useFirestore';
import { clientsQuery } from '@/lib/clientService';
import { mapPatient, isPatient } from '@/lib/clinicService';
import { petsQuery, mapPet, type Pet } from '@/lib/petService';
import { saveVetAppointment, type AppointmentEvent } from '@/lib/eventService';
import { Dialog } from '@/components/ui/Dialog';
import { Button } from '@/components/ui/Button';
import { Select } from '@/components/ui/Select';
import { TextField } from '@/components/ui/TextField';
import { Textarea } from '@/components/ui/Textarea';

function toLocalInput(d: Date): string {
  const p = (n: number) => `${n}`.padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
}

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
  /** Preselect a client (e.g. opened from the client page). */
  presetClientId?: string;
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
  others = [],
}: Props) {
  const isEdit = Boolean(existing);

  const cq = useMemo(() => (vetId ? clientsQuery(vetId) : null), [vetId]);
  const { data: clientDocs } = useCollection<UserProfile>(cq, mapPatient);
  const clients = useMemo(
    () =>
      clientDocs
        .filter(isPatient)
        .sort((a, b) => (a.displayName || a.email).localeCompare(b.displayName || b.email)),
    [clientDocs],
  );

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
      setPetId('');
      setWhen(toLocalInput(defaultStart(defaultDay)));
      setTitle('');
      setTitleTouched(false);
      setLocation('');
      setDescription('');
    }
  }, [open, existing, presetClientId, defaultDay]);

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

  const autoTitle = pet ? `Consulta — ${pet.name}` : 'Consulta';
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
      toast.error('Escolha o cliente.');
      return;
    }
    if (!dateTime || Number.isNaN(dateTime.getTime())) {
      toast.error('Escolha a data e a hora.');
      return;
    }
    setSaving(true);
    try {
      await saveVetAppointment({
        id: existing?.id ?? null,
        clientId,
        clientName:
          client?.displayName || client?.email || existing?.clientName || 'Cliente',
        petId: petId || null,
        petName: pet?.name ?? (petId ? existing?.petName ?? null : null),
        vetId,
        vetName,
        title: effectiveTitle.trim() || 'Consulta',
        description: description.trim(),
        location: location.trim() || null,
        dateTime,
        createdAt: existing?.createdAt ?? null,
        appointmentRequestId: existing?.appointmentRequestId ?? null,
      });
      toast.success(isEdit ? 'Consulta atualizada' : 'Consulta marcada. O cliente já a vê no calendário.');
      onClose();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Não foi possível guardar a consulta');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog
      open={open}
      onClose={() => (saving ? undefined : onClose())}
      title={isEdit ? 'Editar consulta' : 'Nova consulta'}
      description={isEdit ? undefined : 'Fica na agenda e no calendário do cliente.'}
      className="max-w-lg"
      footer={
        <>
          <Button variant="outline" disabled={saving} onClick={onClose}>
            Cancelar
          </Button>
          <Button loading={saving} onClick={() => void submit()}>
            {isEdit ? 'Guardar' : 'Marcar'}
          </Button>
        </>
      }
    >
      <div className="space-y-4">
        <div className="grid gap-4 sm:grid-cols-2">
          <Select
            label="Cliente"
            value={clientId}
            disabled={isEdit}
            onChange={(e) => {
              setClientId(e.target.value);
              setPetId('');
            }}
          >
            <option value="">Escolher…</option>
            {isEdit && !client && existing && (
              <option value={existing.userId}>{existing.clientName || 'Cliente'}</option>
            )}
            {clients.map((c) => (
              <option key={c.id} value={c.id}>
                {c.displayName || c.email}
              </option>
            ))}
          </Select>
          <Select
            label="Animal"
            value={petId}
            disabled={!clientId}
            onChange={(e) => setPetId(e.target.value)}
          >
            <option value="">{clientId && pets.length === 0 ? 'Sem animais' : 'Sem animal'}</option>
            {pets.map((p) => (
              <option key={p.id} value={p.id}>
                {p.species ? `${p.name} (${p.species})` : p.name}
              </option>
            ))}
          </Select>
        </div>

        <TextField
          label="Data e hora"
          type="datetime-local"
          value={when}
          onChange={(e) => setWhen(e.target.value)}
          hint={
            clash
              ? `Atenção: já tem ${clash.clientName || 'uma consulta'} perto desta hora.`
              : undefined
          }
        />

        <TextField
          label="Título"
          value={effectiveTitle}
          onChange={(e) => {
            setTitleTouched(true);
            setTitle(e.target.value);
          }}
        />

        <TextField
          label="Local (opcional)"
          value={location}
          onChange={(e) => setLocation(e.target.value)}
          placeholder="Domicílio, consultório…"
        />

        <Textarea
          label="Notas para o cliente (opcional)"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder="Motivo, preparação, o que trazer…"
        />
      </div>
    </Dialog>
  );
}
