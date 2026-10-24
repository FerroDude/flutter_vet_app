import { Pill, Check, Undo2, Pencil, MoreVertical, Trash2 } from 'lucide-react';
import {
  type Medication,
  MedicationStatus,
  progress,
  isActive,
  allDosesTakenToday,
  daysRemaining,
} from '@vetplus/shared';
import { doseStatusText, frequencyText, nextDoseText } from '@/lib/medText';
import { t, type TKey } from '@/i18n';
import { Card } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Menu } from '@/components/ui/Menu';
import { cn } from '@/lib/cn';

interface Props {
  med: Medication;
  petName?: string;
  onLogDose: () => void;
  onUndo: () => void;
  onEdit: () => void;
  onDelete: () => void;
  onSetStatus: (s: MedicationStatus) => void;
}

const statusKey: Record<MedicationStatus, TKey> = {
  [MedicationStatus.active]: 'meds.status.active',
  [MedicationStatus.paused]: 'meds.status.paused',
  [MedicationStatus.completed]: 'meds.status.completed',
  [MedicationStatus.discontinued]: 'meds.status.discontinued',
};

export function MedicationCard({
  med,
  petName,
  onLogDose,
  onUndo,
  onEdit,
  onDelete,
  onSetStatus,
}: Props) {
  const active = isActive(med);
  const p = progress(med);
  const canTake = active && !allDosesTakenToday(med);
  const remaining = daysRemaining(med);

  return (
    <Card className={cn('p-4', !active && 'opacity-80')}>
      <div className="flex items-start gap-3">
        <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-(--radius-md) bg-primary-light text-primary">
          <Pill size={20} />
        </div>

        <div className="min-w-0 flex-1">
          <div className="flex items-start justify-between gap-2">
            <div className="min-w-0">
              <p className="truncate font-medium text-foreground">{med.name}</p>
              <p className="truncate text-sm text-muted-foreground">
                {med.dosage} · {frequencyText(med.frequency)}
                {petName ? ` · ${petName}` : ''}
              </p>
            </div>
            <Menu
              label={t('meds.options')}
              trigger={<MoreVertical size={16} />}
              items={[
                { label: t('common.edit'), icon: <Pencil size={14} />, onClick: onEdit },
                active
                  ? { label: t('meds.pause'), onClick: () => onSetStatus(MedicationStatus.paused) }
                  : { label: t('meds.resume'), onClick: () => onSetStatus(MedicationStatus.active) },
                { label: t('meds.markCompleted'), onClick: () => onSetStatus(MedicationStatus.completed) },
                { label: t('common.delete'), icon: <Trash2 size={14} />, danger: true, onClick: onDelete },
              ]}
            />
          </div>

          <div className="mt-2 flex flex-wrap items-center gap-2">
            <span
              className={cn(
                'inline-flex items-center rounded-(--radius-pill) px-2 py-0.5 text-xs font-medium',
                active
                  ? 'bg-primary-light text-primary'
                  : 'bg-secondary text-muted-foreground',
              )}
            >
              {t(statusKey[med.status])}
            </span>
            <span className="text-xs text-muted-foreground">{doseStatusText(med)}</span>
          </div>

          {p != null && (
            <div className="mt-3">
              <div className="h-1.5 w-full overflow-hidden rounded-full bg-secondary">
                <div
                  className="h-full rounded-full bg-primary transition-[width]"
                  style={{ width: `${Math.round(p * 100)}%` }}
                />
              </div>
              <div className="mt-1 flex justify-between text-[11px] text-muted-foreground">
                <span>{Math.round(p * 100)}%</span>
                {remaining != null && (
                  <span>{t(remaining === 1 ? 'meds.day.one' : 'meds.day.other', { count: remaining })}</span>
                )}
              </div>
            </div>
          )}

          {active && (
            <div className="mt-3 flex flex-wrap items-center gap-x-2 gap-y-1.5">
              <Button
                size="md"
                variant={canTake ? 'primary' : 'outline'}
                disabled={!canTake}
                onClick={onLogDose}
                className="h-9 px-3 text-xs"
              >
                <Check size={15} /> {t('meds.logDose')}
              </Button>
              <button
                type="button"
                onClick={onUndo}
                className="inline-flex items-center gap-1 text-xs font-medium text-muted-foreground hover:text-foreground"
              >
                <Undo2 size={14} /> {t('common.undo')}
              </button>
              <span className="ml-auto text-[11px] text-muted-foreground">
                {nextDoseText(med) ?? ''}
              </span>
            </div>
          )}
        </div>
      </div>
    </Card>
  );
}
