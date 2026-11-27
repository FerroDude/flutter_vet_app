import { useRef, useState } from 'react';
import { toast } from 'sonner';
import { useAuth } from '@/auth/AuthProvider';
import { useActiveClinic } from '@/app/ClinicProvider';
import { leaveClinic } from '@/lib/clinicService';
import { errorMessage } from '@/lib/format';
import { useConfirm } from '@/components/ui/Confirm';
import { t } from '@/i18n';

export interface LeaveClinicTarget {
  id: string;
  name: string;
}

/**
 * Shared "leave this clinic" flow (profile "As minhas clínicas"). Busy locks
 * ALL leave buttons; a ref guard blocks a fast double-tap. One confirm + one
 * call + one toast. Leaving the ACTIVE clinic with others remaining moves the
 * user explicitly to the first remaining clinic (their own intent, not a side
 * effect); with none remaining the resolved clinicId becomes '' naturally.
 */
export function useLeaveClinic() {
  const { refreshProfile } = useAuth();
  const { clinics, clinicId, setClinicId } = useActiveClinic();
  const confirm = useConfirm();
  const [busy, setBusy] = useState<string | null>(null);
  const inflight = useRef(false);

  const leave = async (target: LeaveClinicTarget) => {
    if (inflight.current) return;
    const ok = await confirm({
      title: t('clinicLeave.title', { name: target.name }),
      description: t('clinicLeave.desc', { name: target.name }),
      confirmLabel: t('clinicLeave.confirm'),
      danger: true,
    });
    if (!ok) return;
    inflight.current = true;
    setBusy(target.id);
    try {
      await leaveClinic(target.id);
      const [next] = clinics.filter((c) => c.id !== target.id);
      let movedTo: string | null = null;
      if (target.id === clinicId && next) {
        setClinicId(next.id);
        movedTo = next.name;
      }
      toast.success(
        movedTo
          ? t('clinicLeave.doneMoved', { name: target.name, other: movedTo })
          : t('clinicLeave.done', { name: target.name }),
      );
      void refreshProfile();
    } catch (e) {
      toast.error(errorMessage(e));
    } finally {
      inflight.current = false;
      setBusy(null);
    }
  };

  return { leave, busy };
}
