import { useEffect, useMemo, useState } from 'react';
import { toast } from 'sonner';
import { type Medication, matchDoseLogs, pastDoseSlots } from '@vetplus/shared';
import { setDoseSlots } from '@/lib/medicationService';
import { errorMessage } from '@/lib/format';
import { t } from '@/i18n';
import { Dialog } from '@/components/ui/Dialog';
import { Button } from '@/components/ui/Button';
import { DoseHistoryGrid } from './DoseHistoryGrid';

/** Edit which past scheduled doses were given (up to 60 days back). */
export function DoseHistoryDialog({
  open,
  onClose,
  uid,
  petId,
  med,
}: {
  open: boolean;
  onClose: () => void;
  uid: string;
  petId: string;
  med: Medication;
}) {
  const slots = useMemo(() => pastDoseSlots(med), [med]);
  const [checked, setChecked] = useState<Set<string>>(new Set());
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (open) setChecked(new Set(matchDoseLogs(med, slots).keys()));
  }, [open, med, slots]);

  const save = async () => {
    const initial = new Set(matchDoseLogs(med, slots).keys());
    const changes = slots
      .filter((s) => checked.has(s.key) !== initial.has(s.key))
      .map((s) => ({ at: s.at, taken: checked.has(s.key) }));
    setSaving(true);
    try {
      await setDoseSlots(uid, petId, med.id, changes);
      toast.success(t('meds.historySaved'));
      onClose();
    } catch (e) {
      toast.error(errorMessage(e, t('meds.saveFailed')));
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog
      open={open}
      onClose={() => (saving ? undefined : onClose())}
      title={t('meds.history')}
      description={t('meds.historyNote')}
      className="max-w-md"
      footer={
        <>
          <Button variant="outline" disabled={saving} onClick={onClose}>
            {t('common.cancel')}
          </Button>
          <Button loading={saving} onClick={() => void save()}>
            {t('common.save')}
          </Button>
        </>
      }
    >
      <DoseHistoryGrid slots={slots} checked={checked} onChange={setChecked} />
    </Dialog>
  );
}
