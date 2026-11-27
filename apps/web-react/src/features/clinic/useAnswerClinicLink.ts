import { useRef, useState } from 'react';
import { toast } from 'sonner';
import { useAuth } from '@/auth/AuthProvider';
import { useActiveClinic } from '@/app/ClinicProvider';
import { respondClinicLink } from '@/lib/clinicService';
import { errorMessage } from '@/lib/format';
import { useConfirm } from '@/components/ui/Confirm';
import { t } from '@/i18n';

export interface ClinicLinkAnswer {
  clinicId: string;
  clinicName: string;
}

/**
 * Shared accept/decline flow for pending clinic links (dashboard banner +
 * profile "As minhas clínicas"). Busy locks BOTH buttons of the answering link;
 * a ref guard blocks a fast double-tap even before state flushes.
 * `answered` hides a link locally until the live links query catches up.
 */
export function useAnswerClinicLink() {
  const { refreshProfile } = useAuth();
  const { announceNewClinic } = useActiveClinic();
  const confirm = useConfirm();
  const [busy, setBusy] = useState<{ clinicId: string; accept: boolean } | null>(null);
  const [answered, setAnswered] = useState<Set<string>>(new Set());
  const inflight = useRef<Set<string>>(new Set());

  const answer = async (link: ClinicLinkAnswer, accept: boolean) => {
    if (inflight.current.has(link.clinicId)) return;
    if (!accept) {
      const ok = await confirm({
        title: t('clinicLink.declineTitle'),
        description: t('clinicLink.declineDesc', { name: link.clinicName }),
        confirmLabel: t('clinicLink.decline'),
        danger: true,
      });
      if (!ok) return;
    }
    inflight.current.add(link.clinicId);
    setBusy({ clinicId: link.clinicId, accept });
    try {
      await respondClinicLink({ clinicId: link.clinicId, accept });
      setAnswered((s) => new Set(s).add(link.clinicId));
      if (accept) {
        announceNewClinic(link.clinicId);
        toast.success(t('clinicLink.accepted', { name: link.clinicName }));
      } else {
        toast.success(t('clinicLink.declined', { name: link.clinicName }));
      }
      void refreshProfile();
    } catch (e) {
      toast.error(errorMessage(e));
    } finally {
      inflight.current.delete(link.clinicId);
      setBusy(null);
    }
  };

  return { answer, busy, answered };
}
