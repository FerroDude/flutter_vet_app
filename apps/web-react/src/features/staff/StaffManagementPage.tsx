import { useMemo, useState } from 'react';
import { toast } from 'sonner';
import {
  UserPlus,
  Stethoscope,
  Headset,
  Mail,
  Trash2,
  Send,
  Hourglass,
  Building2,
} from 'lucide-react';
import { type UserProfile, ClinicRole } from '@vetplus/shared';
import { useAuth } from '@/auth/AuthProvider';
import { useCollection } from '@/lib/useFirestore';
import {
  clinicMembersQuery,
  mapPatient,
  isActiveStaff,
  clinicInvitesQuery,
  mapInvite,
  inviteStaffByEmail,
  revokeStaffInvite,
  resendInvite,
  removeStaffMember,
  type ClinicInvite,
  type InviteRole,
} from '@/lib/clinicService';
import { PageHeader } from '@/components/ui/PageHeader';
import { Card, CardBody } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { TextField } from '@/components/ui/TextField';
import { Dialog } from '@/components/ui/Dialog';
import { EmptyState } from '@/components/ui/EmptyState';

const ROLE_META: Record<
  InviteRole,
  { label: string; plural: string; icon: typeof Stethoscope; clinicRole: ClinicRole }
> = {
  vet: { label: 'Vet', plural: 'Veterinarians', icon: Stethoscope, clinicRole: ClinicRole.vet },
  receptionist: {
    label: 'Receptionist',
    plural: 'Receptionists',
    icon: Headset,
    clinicRole: ClinicRole.receptionist,
  },
};

export function StaffManagementPage() {
  const { firebaseUser, connectedClinic } = useAuth();
  const uid = firebaseUser?.uid ?? '';
  const clinicId = connectedClinic?.id ?? '';

  const [role, setRole] = useState<InviteRole>('vet');
  const meta = ROLE_META[role];

  const membersQ = useMemo(() => (clinicId ? clinicMembersQuery(clinicId) : null), [clinicId]);
  const { data: members } = useCollection<UserProfile>(membersQ, mapPatient);
  const staff = useMemo(
    () => members.filter((m) => isActiveStaff(m) && m.clinicRole === meta.clinicRole),
    [members, meta.clinicRole],
  );

  const invitesQ = useMemo(() => (clinicId ? clinicInvitesQuery(clinicId) : null), [clinicId]);
  const { data: invitesRaw } = useCollection<ClinicInvite>(invitesQ, mapInvite);
  const invites = useMemo(
    () =>
      invitesRaw
        .filter((i) => i.role === role && i.status === 'pending')
        .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime()),
    [invitesRaw, role],
  );

  const [inviteOpen, setInviteOpen] = useState(false);
  const [email, setEmail] = useState('');
  const [inviting, setInviting] = useState(false);
  const [removeTarget, setRemoveTarget] = useState<UserProfile | null>(null);
  const [busy, setBusy] = useState(false);

  const doInvite = async () => {
    const e = email.trim().toLowerCase();
    if (!e || !e.includes('@')) {
      toast.error('Enter a valid email address.');
      return;
    }
    setInviting(true);
    try {
      await inviteStaffByEmail({ clinicId, email: e, role, invitedBy: uid });
      toast.success(`Invitation sent to ${e}`);
      setEmail('');
      setInviteOpen(false);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Could not send invite');
    } finally {
      setInviting(false);
    }
  };

  const doResend = async (inv: ClinicInvite) => {
    try {
      const ok = await resendInvite(inv.email);
      toast[ok ? 'success' : 'error'](ok ? 'Email re-sent' : 'Could not re-send email');
    } catch {
      toast.error('Could not re-send email');
    }
  };

  const doRevoke = async (inv: ClinicInvite) => {
    try {
      await revokeStaffInvite({ clinicId, email: inv.email, role: inv.role });
      toast.success('Invite revoked');
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Could not revoke');
    }
  };

  const doRemove = async () => {
    if (!removeTarget) return;
    setBusy(true);
    try {
      await removeStaffMember(clinicId, removeTarget.id);
      toast.success('Member removed');
      setRemoveTarget(null);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Could not remove');
    } finally {
      setBusy(false);
    }
  };

  if (!connectedClinic) {
    return (
      <div>
        <PageHeader title="Staff" />
        <EmptyState
          icon={<Building2 size={36} />}
          title="No clinic"
          description="Your account isn't linked to a clinic yet."
        />
      </div>
    );
  }

  const Icon = meta.icon;

  return (
    <div>
      <PageHeader
        eyebrow="Team"
        title="Staff"
        subtitle={`Manage ${connectedClinic.name}'s team.`}
        actions={
          <Button onClick={() => setInviteOpen(true)}>
            <UserPlus size={16} /> Invite {meta.label.toLowerCase()}
          </Button>
        }
      />

      <div className="mb-5 inline-flex rounded-(--radius-pill) border border-border/60 bg-card p-1">
        {(Object.keys(ROLE_META) as InviteRole[]).map((r) => (
          <button
            key={r}
            type="button"
            onClick={() => setRole(r)}
            className={
              'rounded-(--radius-pill) px-4 py-1.5 text-sm font-medium transition-colors ' +
              (role === r
                ? 'bg-primary text-primary-foreground'
                : 'text-muted-foreground hover:text-foreground')
            }
          >
            {ROLE_META[r].plural}
          </button>
        ))}
      </div>

      {/* Active members */}
      <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
        Active ({staff.length})
      </h2>
      {staff.length === 0 ? (
        <Card className="mb-6">
          <CardBody className="text-sm text-muted-foreground">
            No active {meta.plural.toLowerCase()} yet.
          </CardBody>
        </Card>
      ) : (
        <div className="mb-6 space-y-3">
          {staff.map((m) => (
            <Card key={m.id}>
              <CardBody className="flex items-center gap-3">
                <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-primary-light text-primary">
                  <Icon size={18} />
                </span>
                <div className="min-w-0 flex-1">
                  <p className="truncate font-medium text-foreground">
                    {m.displayName || m.email}
                  </p>
                  <p className="truncate text-xs text-muted-foreground">{m.email}</p>
                </div>
                <Button variant="ghost" onClick={() => setRemoveTarget(m)}>
                  <Trash2 size={15} /> Remove
                </Button>
              </CardBody>
            </Card>
          ))}
        </div>
      )}

      {/* Pending invites */}
      <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
        Pending invites ({invites.length})
      </h2>
      {invites.length === 0 ? (
        <Card>
          <CardBody className="text-sm text-muted-foreground">No pending invites.</CardBody>
        </Card>
      ) : (
        <div className="space-y-3">
          {invites.map((inv) => (
            <Card key={inv.id}>
              <CardBody className="flex flex-wrap items-center gap-3">
                <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-warning/15 text-warning">
                  <Hourglass size={18} />
                </span>
                <div className="min-w-0 flex-1">
                  <p className="flex items-center gap-1.5 truncate font-medium text-foreground">
                    <Mail size={14} /> {inv.email}
                  </p>
                  <p className="text-xs text-muted-foreground">Invitation pending</p>
                </div>
                <div className="flex gap-2">
                  <Button variant="outline" onClick={() => void doResend(inv)}>
                    <Send size={14} /> Resend
                  </Button>
                  <Button variant="ghost" onClick={() => void doRevoke(inv)}>
                    Revoke
                  </Button>
                </div>
              </CardBody>
            </Card>
          ))}
        </div>
      )}

      {/* Invite dialog */}
      <Dialog
        open={inviteOpen}
        onClose={() => (inviting ? undefined : setInviteOpen(false))}
        title={`Invite a ${meta.label.toLowerCase()}`}
        description="They'll receive an email to set a password and join your clinic."
        footer={
          <>
            <Button variant="outline" disabled={inviting} onClick={() => setInviteOpen(false)}>
              Cancel
            </Button>
            <Button loading={inviting} onClick={() => void doInvite()}>
              Send invite
            </Button>
          </>
        }
      >
        <TextField
          label="Email address"
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="name@example.com"
        />
      </Dialog>

      {/* Remove confirm */}
      <Dialog
        open={Boolean(removeTarget)}
        onClose={() => (busy ? undefined : setRemoveTarget(null))}
        title="Remove member"
        description={
          removeTarget
            ? `Remove ${removeTarget.displayName || removeTarget.email} from the clinic? They'll lose access.`
            : ''
        }
        footer={
          <>
            <Button variant="outline" disabled={busy} onClick={() => setRemoveTarget(null)}>
              Cancel
            </Button>
            <Button variant="destructive" loading={busy} onClick={() => void doRemove()}>
              Remove
            </Button>
          </>
        }
      />
    </div>
  );
}
