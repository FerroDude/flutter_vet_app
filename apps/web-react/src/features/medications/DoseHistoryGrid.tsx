import { useMemo } from 'react';
import { type DoseSlot, doseSlotKey } from '@vetplus/shared';
import { dayKey, dayShortFmt, timeFmt } from '@/lib/format';
import { t } from '@/i18n';

/**
 * Checkbox grid of past dose slots: one row per day (newest first), one
 * column per distinct time of day. Days without a slot in a column stay empty.
 */
export function DoseHistoryGrid({
  slots,
  checked,
  onChange,
}: {
  slots: DoseSlot[];
  checked: Set<string>;
  onChange: (next: Set<string>) => void;
}) {
  const { days, times } = useMemo(() => {
    const byDay = new Map<string, DoseSlot[]>();
    const times = new Map<string, string>();
    for (const s of slots) {
      const dk = dayKey(s.day);
      (byDay.get(dk) ?? byDay.set(dk, []).get(dk)!).push(s);
      times.set(doseSlotKey(s.at).slice(11), doseSlotKey(s.at).slice(11));
    }
    const days = [...byDay.entries()]
      .map(([k, list]) => ({ key: k, day: list[0]!.day, slots: list }))
      .sort((a, b) => b.day.getTime() - a.day.getTime());
    return { days, times: [...times.keys()].sort() };
  }, [slots]);

  const toggle = (key: string, on: boolean) => {
    const next = new Set(checked);
    if (on) next.add(key);
    else next.delete(key);
    onChange(next);
  };

  const setAll = (on: boolean) => onChange(on ? new Set(slots.map((s) => s.key)) : new Set());

  const slotAt = (daySlots: DoseSlot[], time: string) =>
    daySlots.find((s) => s.key.slice(11) === time);

  if (slots.length === 0) return null;

  return (
    <div>
      <div className="mb-2 flex gap-2">
        <button
          type="button"
          onClick={() => setAll(true)}
          className="text-xs font-medium text-primary hover:underline"
        >
          {t('meds.checkAll')}
        </button>
        <button
          type="button"
          onClick={() => setAll(false)}
          className="text-xs font-medium text-muted-foreground hover:underline"
        >
          {t('meds.clearAll')}
        </button>
      </div>
      <div className="max-h-64 overflow-auto rounded-(--radius-md) border border-border">
        <table className="w-full text-sm">
          <thead className="sticky top-0 bg-card">
            <tr className="border-b border-border text-left text-xs text-muted-foreground">
              <th className="px-3 py-2 font-medium">{t('common.date')}</th>
              {times.map((time) => (
                <th key={time} className="px-2 py-2 text-center font-medium tabular-nums">
                  {time}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-border">
            {days.map(({ key, day, slots: daySlots }) => (
              <tr key={key}>
                <td className="whitespace-nowrap px-3 py-1.5 text-xs text-foreground">
                  {dayShortFmt.format(day)}
                </td>
                {times.map((time) => {
                  const slot = slotAt(daySlots, time);
                  return (
                    <td key={time} className="px-2 py-1.5 text-center">
                      {slot && (
                        <input
                          type="checkbox"
                          checked={checked.has(slot.key)}
                          onChange={(e) => toggle(slot.key, e.target.checked)}
                          aria-label={`${dayShortFmt.format(day)} ${timeFmt.format(slot.at)}`}
                          className="h-4 w-4 accent-[hsl(var(--primary))]"
                        />
                      )}
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
