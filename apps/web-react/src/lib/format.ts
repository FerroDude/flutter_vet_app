// Shared pt-PT date formatting, day helpers and request labels.

import { AppointmentRequestStatus, TimePreference } from '@vetplus/shared';

const fmt = (o: Intl.DateTimeFormatOptions) => new Intl.DateTimeFormat('pt-PT', o);

/** 14:30 */
export const timeFmt = fmt({ hour: '2-digit', minute: '2-digit', hourCycle: 'h23' });
/** 23 out */
export const shortDateFmt = fmt({ day: 'numeric', month: 'short' });
/** sex, 23 out, 14:30 */
export const dateTimeFmt = fmt({
  weekday: 'short',
  day: 'numeric',
  month: 'short',
  hour: '2-digit',
  minute: '2-digit',
  hourCycle: 'h23',
});
/** sexta-feira, 23 de outubro */
export const dayHeadFmt = fmt({ weekday: 'long', day: 'numeric', month: 'long' });
/** sex, 23 out */
export const dayShortFmt = fmt({ weekday: 'short', day: 'numeric', month: 'short' });
/** 23 de outubro de 2026 */
export const longDateFmt = fmt({ day: 'numeric', month: 'long', year: 'numeric' });
/** outubro de 2026 */
export const monthFmt = fmt({ month: 'long', year: 'numeric' });

export const dayKey = (d: Date): string => `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
export const sameDay = (a: Date, b: Date): boolean => dayKey(a) === dayKey(b);
export const startOfDay = (d: Date): Date => new Date(d.getFullYear(), d.getMonth(), d.getDate());

/** "Bom dia" / "Boa tarde" / "Boa noite" */
export function greeting(now = new Date()): string {
  const h = now.getHours();
  return h < 12 ? 'Bom dia' : h < 18 ? 'Boa tarde' : 'Boa noite';
}

export const TIME_PREFERENCE_LABEL: Record<TimePreference, string> = {
  [TimePreference.anyTime]: 'Qualquer hora',
  [TimePreference.morning]: 'Manhã',
  [TimePreference.afternoon]: 'Tarde',
  [TimePreference.evening]: 'Noite',
};

/** Hour window [from, to) each time preference covers; null = any time. */
export const TIME_WINDOW: Record<TimePreference, [number, number] | null> = {
  [TimePreference.anyTime]: null,
  [TimePreference.morning]: [8, 12],
  [TimePreference.afternoon]: [12, 17],
  [TimePreference.evening]: [17, 20],
};

/** "Qualquer hora" | "Manhã (8h – 12h)" | "Tarde (12h – 17h)" | "Noite (17h – 20h)" */
export function timePreferenceText(p: TimePreference): string {
  const w = TIME_WINDOW[p];
  return w ? `${TIME_PREFERENCE_LABEL[p]} (${w[0]}h – ${w[1]}h)` : TIME_PREFERENCE_LABEL[p];
}

export const REQUEST_STATUS: Record<AppointmentRequestStatus, { label: string; classes: string }> = {
  [AppointmentRequestStatus.pending]: { label: 'Pendente', classes: 'bg-warning/15 text-warning' },
  [AppointmentRequestStatus.confirmed]: { label: 'Confirmado', classes: 'bg-primary-light text-primary' },
  [AppointmentRequestStatus.denied]: { label: 'Recusado', classes: 'bg-destructive/15 text-destructive' },
  [AppointmentRequestStatus.cancelled]: { label: 'Cancelado', classes: 'bg-muted text-muted-foreground' },
};

/** "23 out" or "23 out – 25 out" */
export function preferredRange(start: Date, end: Date): string {
  const a = shortDateFmt.format(start);
  const b = shortDateFmt.format(end);
  return a === b ? a : `${a} – ${b}`;
}

export function errorMessage(e: unknown, fallback = 'Algo correu mal. Tente de novo.'): string {
  return e instanceof Error && e.message ? e.message : fallback;
}
