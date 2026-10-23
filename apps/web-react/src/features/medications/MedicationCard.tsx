import { Pill, Check, Undo2, Pencil, MoreVertical, Trash2 } from 'lucide-react';
import {
  type Medication,
  MedicationStatus,
  frequencyDisplay,
  todayDoseStatus,
  nextDoseDescription,
  progress,
  isActive,
  allDosesTakenToday,
  daysRemaining,
} from '@vetplus/shared';
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

const statusLabel: Record<MedicationStatus, string> = {
  [MedicationStatus.active]: 'Ativa',
  [MedicationStatus.paused]: 'Em pausa',
  [MedicationStatus.completed]: 'Concluída',
  [MedicationStatus.discontinued]: 'Interrompida',
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
                {med.dosage} · {frequencyDisplay(med.frequency)}
                {petName ? ` · ${petName}` : ''}
              </p>
            </div>
            <Menu
              label="Opções da medicação"
              trigger={<MoreVertical size={16} />}
              items={[
                { label: 'Editar', icon: <Pencil size={14} />, onClick: onEdit },
                active
                  ? { label: 'Pausar', onClick: () => onSetStatus(MedicationStatus.paused) }
                  : { label: 'Retomar', onClick: () => onSetStatus(MedicationStatus.active) },
                { label: 'Marcar como concluída', onClick: () => onSetStatus(MedicationStatus.completed) },
                { label: 'Apagar', icon: <Trash2 size={14} />, danger: true, onClick: onDelete },
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
              {statusLabel[med.status]}
            </span>
            <span className="text-xs text-muted-foreground">{todayDoseStatus(med)}</span>
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
                  <span>{remaining === 1 ? '1 dia' : `${remaining} dias`}</span>
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
                <Check size={15} /> Registar dose
              </Button>
              <button
                type="button"
                onClick={onUndo}
                className="inline-flex items-center gap-1 text-xs font-medium text-muted-foreground hover:text-foreground"
              >
                <Undo2 size={14} /> Anular
              </button>
              <span className="ml-auto text-[11px] text-muted-foreground">
                {nextDoseDescription(med) ?? ''}
              </span>
            </div>
          )}
        </div>
      </div>
    </Card>
  );
}
