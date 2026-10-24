import { useId } from 'react';
import { cn } from '@/lib/cn';
import { inputBase } from './TextField';
import { fieldLabelClasses, selectChevronStyle, selectClasses } from './Select';
import { t } from '@/i18n';

const pad = (n: number) => `${n}`.padStart(2, '0');

/** Minutes selectable for a given hour. When `hour === maxHour` and maxHour is a
 *  real upper bound (not 23), only :00 is valid. An off-grid `current` minute is
 *  kept as an option so an existing value is never lost. */
export function minuteOptions(
  hour: number,
  maxHour: number,
  step: number,
  current?: number,
): number[] {
  if (hour === maxHour && maxHour !== 23) {
    return current != null && current !== 0 ? [0, current] : [0];
  }
  const opts: number[] = [];
  for (let m = 0; m < 60; m += Math.max(1, step)) opts.push(m);
  if (current != null && !opts.includes(current)) {
    opts.push(current);
    opts.sort((a, b) => a - b);
  }
  return opts;
}

interface TimeFieldProps {
  label?: string;
  value: string; // "HH:mm"
  onChange: (v: string) => void;
  minHour?: number;
  maxHour?: number;
  minuteStep?: number;
  className?: string;
}

export function TimeField({
  label,
  value,
  onChange,
  minHour = 0,
  maxHour = 23,
  minuteStep = 5,
  className,
}: TimeFieldProps) {
  const autoId = useId();
  const [hStr, mStr] = value.split(':');
  const hour = Number(hStr) || 0;
  const minute = Number(mStr) || 0;
  const bounded = maxHour !== 23;

  const hours: number[] = [];
  for (let h = minHour; h <= maxHour; h++) hours.push(h);
  if (!hours.includes(hour)) hours.push(hour);
  hours.sort((a, b) => a - b);

  const minutes = minuteOptions(hour, maxHour, minuteStep, minute);

  const emit = (h: number, m: number) => onChange(`${pad(h)}:${pad(m)}`);

  const selects = (
    <div className={cn('flex items-center gap-1.5', className)}>
      <select
        id={label ? autoId : undefined}
        aria-label={label ? undefined : t('time.hour')}
        value={hour}
        onChange={(e) => {
          const h = Number(e.target.value);
          emit(h, h === maxHour && bounded ? 0 : minute);
        }}
        className={cn(selectClasses, 'w-auto')}
        style={selectChevronStyle}
      >
        {hours.map((h) => (
          <option key={h} value={h}>
            {pad(h)}
          </option>
        ))}
      </select>
      <span className="text-sm font-medium text-muted-foreground">:</span>
      <select
        aria-label={label ? undefined : t('time.minutes')}
        value={minute}
        onChange={(e) => emit(hour, Number(e.target.value))}
        className={cn(selectClasses, 'w-auto')}
        style={selectChevronStyle}
      >
        {minutes.map((m) => (
          <option key={m} value={m}>
            {pad(m)}
          </option>
        ))}
      </select>
    </div>
  );

  if (!label) return selects;
  return (
    <div className="flex flex-col gap-1.5">
      <label htmlFor={autoId} className={fieldLabelClasses}>
        {label}
      </label>
      {selects}
    </div>
  );
}

interface DateTimeFieldProps {
  label: string;
  value: string; // "YYYY-MM-DDTHH:mm"
  onChange: (v: string) => void;
  minuteStep?: number;
  hint?: string;
}

export function DateTimeField({ label, value, onChange, minuteStep, hint }: DateTimeFieldProps) {
  const autoId = useId();
  const [date = '', time = ''] = value.split('T');
  return (
    <div className="flex flex-col gap-1.5">
      <label htmlFor={autoId} className={fieldLabelClasses}>
        {label}
      </label>
      <div className="grid grid-cols-[1fr_auto] items-center gap-2">
        <input
          id={autoId}
          type="date"
          value={date}
          onChange={(e) => onChange(e.target.value ? `${e.target.value}T${time || '09:00'}` : '')}
          className={cn(inputBase, 'border-input')}
        />
        <TimeField
          value={time || '09:00'}
          onChange={(t) => date && onChange(`${date}T${t}`)}
          minuteStep={minuteStep}
        />
      </div>
      {hint && <p className="text-xs text-muted-foreground">{hint}</p>}
    </div>
  );
}
