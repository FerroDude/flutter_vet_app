import { useEffect, useState } from 'react';
import { toast } from 'sonner';
import { createClinicForAdmin } from '@/lib/clinicService';
import { Dialog } from '@/components/ui/Dialog';
import { Button } from '@/components/ui/Button';
import { TextField } from '@/components/ui/TextField';
import { Textarea } from '@/components/ui/Textarea';

interface Props {
  open: boolean;
  onClose: () => void;
  onCreated?: (clinicId: string) => void;
}

export function CreateClinicDialog({ open, onClose, onCreated }: Props) {
  const [name, setName] = useState('');
  const [address, setAddress] = useState('');
  const [phone, setPhone] = useState('');
  const [email, setEmail] = useState('');
  const [website, setWebsite] = useState('');
  const [description, setDescription] = useState('');
  const [adminName, setAdminName] = useState('');
  const [adminEmail, setAdminEmail] = useState('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (open) {
      setName('');
      setAddress('');
      setPhone('');
      setEmail('');
      setWebsite('');
      setDescription('');
      setAdminName('');
      setAdminEmail('');
    }
  }, [open]);

  const submit = async () => {
    if (!name.trim()) {
      toast.error('Clinic name is required.');
      return;
    }
    if (!adminEmail.trim() || !adminEmail.includes('@')) {
      toast.error('A valid admin email is required.');
      return;
    }
    setSaving(true);
    try {
      const id = await createClinicForAdmin({
        name,
        address,
        phone,
        email,
        website,
        description,
        adminEmail,
        adminName,
      });
      toast.success('Clinic created — admin invited by email');
      onCreated?.(id);
      onClose();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not create clinic');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog
      open={open}
      onClose={() => (saving ? undefined : onClose())}
      title="Create a clinic"
      description="The admin will receive an email to set their password and take ownership."
      footer={
        <>
          <Button variant="outline" disabled={saving} onClick={onClose}>
            Cancel
          </Button>
          <Button loading={saving} onClick={() => void submit()}>
            Create clinic
          </Button>
        </>
      }
    >
      <div className="space-y-4">
        <TextField label="Clinic name" value={name} onChange={(e) => setName(e.target.value)} />
        <TextField label="Address" value={address} onChange={(e) => setAddress(e.target.value)} />
        <div className="grid gap-4 sm:grid-cols-2">
          <TextField label="Phone" value={phone} onChange={(e) => setPhone(e.target.value)} />
          <TextField label="Clinic email" value={email} onChange={(e) => setEmail(e.target.value)} />
        </div>
        <TextField label="Website (optional)" value={website} onChange={(e) => setWebsite(e.target.value)} />
        <Textarea
          label="Description (optional)"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
        />

        <div className="rounded-(--radius-md) border border-border bg-secondary/50 p-4">
          <p className="mb-3 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
            Clinic administrator
          </p>
          <div className="grid gap-4 sm:grid-cols-2">
            <TextField
              label="Admin name"
              value={adminName}
              onChange={(e) => setAdminName(e.target.value)}
            />
            <TextField
              label="Admin email"
              type="email"
              value={adminEmail}
              onChange={(e) => setAdminEmail(e.target.value)}
              placeholder="admin@example.com"
            />
          </div>
        </div>
      </div>
    </Dialog>
  );
}
