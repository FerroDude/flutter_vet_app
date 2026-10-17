import { useMemo, useState } from 'react';
import { toast } from 'sonner';
import { Plus, Building2, Search, Trash2, Mail, Phone, MapPin } from 'lucide-react';
import { type Clinic } from '@vetplus/shared';
import { useCollection } from '@/lib/useFirestore';
import { allClinicsQuery, mapClinic, deleteClinicAsOwner } from '@/lib/clinicService';
import { PageHeader } from '@/components/ui/PageHeader';
import { Card, CardBody } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Dialog } from '@/components/ui/Dialog';
import { EmptyState } from '@/components/ui/EmptyState';
import { CreateClinicDialog } from './CreateClinicDialog';

export function ClinicsAdminPage() {
  const { data: clinics } = useCollection<Clinic>(allClinicsQuery(), mapClinic);

  const [search, setSearch] = useState('');
  const list = useMemo(() => {
    const s = search.trim().toLowerCase();
    const filtered = s
      ? clinics.filter(
          (c) =>
            c.name.toLowerCase().includes(s) ||
            (c.address ?? '').toLowerCase().includes(s) ||
            (c.email ?? '').toLowerCase().includes(s),
        )
      : clinics;
    return [...filtered].sort((a, b) => a.name.localeCompare(b.name));
  }, [clinics, search]);

  const [createOpen, setCreateOpen] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<Clinic | null>(null);
  const [deleting, setDeleting] = useState(false);

  const doDelete = async () => {
    if (!deleteTarget) return;
    setDeleting(true);
    try {
      await deleteClinicAsOwner(deleteTarget.id);
      toast.success('Clinic deleted');
      setDeleteTarget(null);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not delete clinic');
    } finally {
      setDeleting(false);
    }
  };

  return (
    <div>
      <PageHeader
        eyebrow="Platform"
        title="Clinics"
        subtitle="All clinics on the platform."
        actions={
          <Button onClick={() => setCreateOpen(true)}>
            <Plus size={16} /> New clinic
          </Button>
        }
      />

      <div className="relative mb-5">
        <Search
          size={16}
          className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground"
        />
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search clinics…"
          className="h-11 w-full rounded-(--radius-md) border border-input bg-card pl-9 pr-3 text-sm text-foreground focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring"
        />
      </div>

      {list.length === 0 ? (
        <EmptyState
          icon={<Building2 size={36} />}
          title={search ? 'No matches' : 'No clinics yet'}
          description={search ? 'Try a different search.' : 'Create the first clinic to get started.'}
          action={search ? undefined : <Button onClick={() => setCreateOpen(true)}>Create clinic</Button>}
        />
      ) : (
        <div className="space-y-3">
          {list.map((c) => (
            <Card key={c.id}>
              <CardBody className="flex flex-wrap items-start gap-3">
                <span className="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-primary-light text-primary">
                  <Building2 size={20} />
                </span>
                <div className="min-w-0 flex-1">
                  <p className="flex items-center gap-2 font-medium text-foreground">
                    {c.name}
                    {!c.isActive && (
                      <span className="rounded-full bg-muted px-2 py-0.5 text-[11px] font-medium text-muted-foreground">
                        Inactive
                      </span>
                    )}
                  </p>
                  <div className="mt-1 flex flex-wrap items-center gap-x-4 gap-y-0.5 text-xs text-muted-foreground">
                    {c.address && (
                      <span className="inline-flex items-center gap-1">
                        <MapPin size={12} /> {c.address}
                      </span>
                    )}
                    {c.phone && (
                      <span className="inline-flex items-center gap-1">
                        <Phone size={12} /> {c.phone}
                      </span>
                    )}
                    {c.email && (
                      <span className="inline-flex items-center gap-1">
                        <Mail size={12} /> {c.email}
                      </span>
                    )}
                  </div>
                </div>
                <Button variant="ghost" onClick={() => setDeleteTarget(c)}>
                  <Trash2 size={15} /> Delete
                </Button>
              </CardBody>
            </Card>
          ))}
        </div>
      )}

      <CreateClinicDialog open={createOpen} onClose={() => setCreateOpen(false)} />

      <Dialog
        open={Boolean(deleteTarget)}
        onClose={() => (deleting ? undefined : setDeleteTarget(null))}
        title="Delete clinic"
        description={
          deleteTarget
            ? `Permanently delete ${deleteTarget.name}? Staff and pet owners will be unlinked. This cannot be undone.`
            : ''
        }
        footer={
          <>
            <Button variant="outline" disabled={deleting} onClick={() => setDeleteTarget(null)}>
              Cancel
            </Button>
            <Button variant="destructive" loading={deleting} onClick={() => void doDelete()}>
              Delete clinic
            </Button>
          </>
        }
      />
    </div>
  );
}
