import { useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { toast } from 'sonner';
import { useAuth } from '@/auth/AuthProvider';
import { useFoundReports } from '@/lib/petTagService';
import { notifyOs } from '@/features/chat/incomingMessage';
import { t } from '@/i18n';

/** Always-on alert when someone reports one of the client's pets found.
 *  Baselines reports that exist on first load, then toasts each new one —
 *  independent of the chat toasts (no active-room suppression). */
export function FoundReportToast() {
  const { firebaseUser } = useAuth();
  const navigate = useNavigate();
  const uid = firebaseUser?.uid ?? '';
  const { reports, loading } = useFoundReports(uid);
  const seen = useRef<Set<string> | null>(null);

  useEffect(() => {
    if (!uid || loading) return;
    if (!seen.current) {
      seen.current = new Set(reports.map((r) => r.id));
      return;
    }
    for (const r of reports) {
      if (seen.current.has(r.id)) continue;
      seen.current.add(r.id);
      const description = [r.finderName || t('tag.someone'), r.finderContact, r.message]
        .filter(Boolean)
        .join(' · ');
      const open = () => navigate('/');
      toast(t('tag.foundToast', { name: r.petName }), {
        id: `found-${r.id}`,
        description,
        duration: 15000,
        action: { label: t('common.view'), onClick: open },
      });
      notifyOs(t('tag.foundToast', { name: r.petName }), description, open);
    }
  }, [reports, loading, uid, navigate]);

  return null;
}
