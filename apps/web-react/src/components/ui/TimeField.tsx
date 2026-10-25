import { useId } from 'react';
import { cn } from '@/lib/cn';
import { inputBase } from './TextField';
import { fieldLabelClasses, selectChevronStyle, selectClasses } from './Select';
import { t } from '@/i18n';

const pad = (n: number) => `${n}`.padStart(2, '0');
const fmt = (mins: number) => `${pad(Math.floor(mins / 60))}:${pad(mins % 60)}`;

/** "HH:mm" options from minHour:00 every `step` minutes. A real upper bound
 *  (maxHour < 23) ends at maxHour:00; otherwise the list runs to the end of the
 *  day. An off-grid `current` value is kept so an existing time is never lost. */
export function timeOptions(minHour: number, maxHour: number, step: number, current?: string): string[] {
  const end = maxHour < 23 ? maxHour * 60 : 24 * 60 - 1;
  const opts: string[] = [];
  for (let m = minHour * 60; m <= end; m += Math.max(1, step)) opts.push(fmt(m));
  if (current && !opts.includes(current)) {
    opts.push(current);
    opts.sort();
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
  minuteStep = 15,
  className,
}: TimeFieldProps) {
  const autoId = useId();
  const select = (
    <select
      id={label ? autoId : undefined}
      aria-label={label ? undefined : t('time.hour')}
      value={value}
      onChange={(e) => onChange(e.target.value)}
      className={cn(selectClasses, 'tabular-nums', className)}
      style={selectChevronStyle}
    >
      {timeOptions(minHour, maxHour, minuteStep, value).map((o) => (
        <option key={o} value={o}>
          {o}
        </option>
      ))}
    </select>
  );

  if (!label) return select;
  return (
    <div className="flex flex-col gap-1.5">
      <label htmlFor={autoId} className={fieldLabelClasses}>
        {label}
      </label>
      {select}
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
      <div className="grid grid-cols-[minmax(0,1fr)_6.5rem] items-center gap-2">
        <input
          id={autoId}
          type="date"
          value={date}
          onChange={(e) => onChange(e.target.value ? `${e.target.value}T${time || '09:00'}` : '')}
          className={cn(inputBase, 'min-w-0 border-input')}
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
