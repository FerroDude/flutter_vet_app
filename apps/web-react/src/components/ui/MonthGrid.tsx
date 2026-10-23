import { type ReactNode } from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { cn } from '@/lib/cn';
import { dayHeadFmt, monthFmt, sameDay, startOfDay } from '@/lib/format';
import { Card } from './Card';

const WEEKDAYS = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

/** Month cells, Monday first; null pads the first week. */
function monthCells(month: Date): (Date | null)[] {
  const lead = (new Date(month.getFullYear(), month.getMonth(), 1).getDay() + 6) % 7;
  const days = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
  const cells: (Date | null)[] = Array.from({ length: lead }, () => null);
  for (let d = 1; d <= days; d++) cells.push(new Date(month.getFullYear(), month.getMonth(), d));
  return cells;
}

/**
 * Month calendar with prev/today/next. `marks` renders the small indicator
 * under each day number (dots, a count…).
 */
export function MonthGrid({
  month,
  selected,
  onMonthChange,
  onSelect,
  marks,
}: {
  month: Date;
  selected: Date;
  onMonthChange: (m: Date) => void;
  onSelect: (d: Date) => void;
  marks?: (day: Date, selected: boolean) => ReactNode;
}) {
  const today = startOfDay(new Date());
  const shift = (n: number) => onMonthChange(new Date(month.getFullYear(), month.getMonth() + n, 1));

  return (
    <Card className="p-4">
      <div className="mb-4 flex items-center justify-between">
        <h2 className="font-display text-lg font-semibold text-foreground first-letter:uppercase">
          {monthFmt.format(month)}
        </h2>
        <div className="flex items-center gap-1">
          <NavBtn label="Mês anterior" onClick={() => shift(-1)}>
            <ChevronLeft size={18} />
          </NavBtn>
          <button
            type="button"
            onClick={() => {
              onMonthChange(new Date(today.getFullYear(), today.getMonth(), 1));
              onSelect(today);
            }}
            className="rounded-(--radius-sm) px-2 py-1 text-xs font-medium text-muted-foreground hover:bg-secondary"
          >
            Hoje
          </button>
          <NavBtn label="Mês seguinte" onClick={() => shift(1)}>
            <ChevronRight size={18} />
          </NavBtn>
        </div>
      </div>

      <div className="grid grid-cols-7 gap-1">
        {WEEKDAYS.map((w) => (
          <div key={w} className="pb-1 text-center text-xs font-medium text-muted-foreground">
            {w}
          </div>
        ))}
        {monthCells(month).map((cell, i) => {
          if (!cell) return <div key={i} />;
          const isSelected = sameDay(cell, selected);
          const isToday = sameDay(cell, today);
          return (
            <button
              key={i}
              type="button"
              onClick={() => onSelect(cell)}
              aria-label={dayHeadFmt.format(cell)}
              aria-pressed={isSelected}
              className={cn(
                'flex aspect-square flex-col items-center justify-start rounded-(--radius-sm) p-1 text-sm transition-colors',
                isSelected ? 'bg-primary text-primary-foreground' : 'text-foreground hover:bg-secondary',
              )}
            >
              <span
                className={cn(
                  'flex h-6 w-6 items-center justify-center rounded-full text-xs',
                  isToday && !isSelected && 'bg-primary-light font-semibold text-primary',
                )}
              >
                {cell.getDate()}
              </span>
              {marks?.(cell, isSelected)}
            </button>
          );
        })}
      </div>
    </Card>
  );
}

function NavBtn({ children, onClick, label }: { children: ReactNode; onClick: () => void; label: string }) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      className="rounded-(--radius-sm) p-1.5 text-muted-foreground hover:bg-secondary hover:text-foreground"
    >
      {children}
    </button>
  );
}

/** Coloured dots for MonthGrid marks. */
export function Dots({ colors, selected }: { colors: string[]; selected: boolean }) {
  if (colors.length === 0) return null;
  return (
    <span className="mt-0.5 flex h-1.5 gap-0.5">
      {colors.map((c) => (
        <span key={c} className={cn('h-1.5 w-1.5 rounded-full', selected ? 'bg-primary-foreground' : c)} />
      ))}
    </span>
  );
}
