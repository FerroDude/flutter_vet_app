// Pure helpers for the client-requested appointment window (date interval +
// time of day). Kept firebase-free so they can be unit-tested and reused by
// the confirm dialog and the service layer.

import { type AppointmentRequest } from '@vetplus/shared';
import { dayShortFmt, startOfDay, TIME_WINDOW } from './format';
import { t } from '@/i18n';

type Windowed = Pick<
  AppointmentRequest,
  'preferredDateStart' | 'preferredDateEnd' | 'timePreference'
>;

/** Error message when `dateTime` falls outside the requested window, else null. */
export function requestWindowError(r: Windowed, dateTime: Date): string | null {
  const day = startOfDay(dateTime).getTime();
  const start = startOfDay(r.preferredDateStart).getTime();
  const end = startOfDay(r.preferredDateEnd).getTime();
  if (day < start || day > end) {
    return t('requests.window.day', {
      from: dayShortFmt.format(r.preferredDateStart),
      to: dayShortFmt.format(r.preferredDateEnd),
    });
  }
  const w = TIME_WINDOW[r.timePreference];
  if (w) {
    const mins = dateTime.getHours() * 60 + dateTime.getMinutes();
    if (mins < w[0] * 60 || mins > w[1] * 60) {
      return t('requests.window.time', { from: w[0], to: w[1] });
    }
  }
  return null;
}

/** Sensible default slot inside the requested window for the confirm dialog. */
export function defaultRequestSlot(r: Windowed, now = new Date()): Date {
  const start = startOfDay(r.preferredDateStart);
  const end = startOfDay(r.preferredDateEnd);
  const today = startOfDay(now);
  const day = today.getTime() > start.getTime() && today.getTime() <= end.getTime() ? today : start;
  const w = TIME_WINDOW[r.timePreference];
  const d = new Date(day);
  d.setHours(w ? w[0] : 9, 0, 0, 0);
  return d;
}
