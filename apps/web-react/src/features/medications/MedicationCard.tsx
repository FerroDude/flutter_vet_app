import { Pill, Check, Undo2, Pencil, MoreVertical, Trash2 } from 'lucide-react';
import { useState } from 'react';
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
  [MedicationStatus.active]: 'Active',
  [MedicationStatus.paused]: 'Paused',
  [MedicationStatus.completed]: 'Completed',
  [MedicationStatus.discontinued]: 'Discontinued',
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
  const [menuOpen, setMenuOpen] = useState(false);
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
            <div className="relative">
              <button
                type="button"
                onClick={() => setMenuOpen((o) => !o)}
                onBlur={() => setTimeout(() => setMenuOpen(false), 150)}
                className="rounded-(--radius-sm) p-1.5 text-muted-foreground hover:bg-secondary"
                aria-label="Medication options"
              >
                <MoreVertical size={16} />
              </button>
              {menuOpen && (
                <div className="absolute right-0 z-10 mt-1 w-44 overflow-hidden rounded-(--radius-md) border border-border bg-card py-1 shadow-(--shadow-md)">
                  <MenuItem onClick={onEdit} icon={<Pencil size={14} />}>
                    Edit
                  </MenuItem>
                  {active ? (
                    <MenuItem onClick={() => onSetStatus(MedicationStatus.paused)}>
                      Pause
                    </MenuItem>
                  ) : (
                    <MenuItem onClick={() => onSetStatus(MedicationStatus.active)}>
                      Resume
                    </MenuItem>
                  )}
                  <MenuItem onClick={() => onSetStatus(MedicationStatus.completed)}>
                    Mark completed
                  </MenuItem>
                  <MenuItem
                    onClick={onDelete}
                    icon={<Trash2 size={14} />}
                    danger
                  >
                    Delete
                  </MenuItem>
                </div>
              )}
            </div>
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
                {remaining != null && <span>{remaining} days left</span>}
              </div>
            </div>
          )}

          {active && (
            <div className="mt-3 flex items-center gap-2">
              <Button
                size="md"
                variant={canTake ? 'primary' : 'outline'}
                disabled={!canTake}
                onClick={onLogDose}
                className="h-9 px-3 text-xs"
              >
                <Check size={15} /> Mark dose taken
              </Button>
              <button
                type="button"
                onClick={onUndo}
                className="inline-flex items-center gap-1 text-xs font-medium text-muted-foreground hover:text-foreground"
              >
                <Undo2 size={14} /> Undo
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

function MenuItem({
  children,
  onClick,
  icon,
  danger,
}: {
  children: React.ReactNode;
  onClick: () => void;
  icon?: React.ReactNode;
  danger?: boolean;
}) {
  return (
    <button
      type="button"
      onMouseDown={(e) => {
        e.preventDefault();
        onClick();
      }}
      className={cn(
        'flex w-full items-center gap-2 px-3 py-2 text-left text-sm hover:bg-secondary',
        danger ? 'text-destructive' : 'text-foreground',
      )}
    >
      {icon}
      {children}
    </button>
  );
}
