// Locale-aware labels for shared medication/symptom helpers (shared keeps its
// own pt strings; UI renders through t()).

import {
  MedicationFrequency,
  allDosesTakenToday,
  daysUntilStart,
  dosesExpectedToday,
  dosesTakenToday,
  endedIncomplete,
  hasEnded,
  hasStarted,
  isBehindSchedule,
  missedDoses,
  nextDose,
  totalDosesTaken,
  type Medication,
  type SymptomType,
} from '@vetplus/shared';
import { startOfDay } from './format';
import { t, type TKey } from '@/i18n';

const diffDays = (a: Date, b: Date): number =>
  Math.round((startOfDay(a).getTime() - startOfDay(b).getTime()) / 86_400_000);

export function symptomLabel(type: SymptomType): string {
  return t(`symptoms.${type}` as TKey);
}

const FREQ_KEY: Record<MedicationFrequency, TKey> = {
  [MedicationFrequency.once]: 'meds.freq.once',
  [MedicationFrequency.daily]: 'meds.freq.daily',
  [MedicationFrequency.twiceDaily]: 'meds.freq.twiceDaily',
  [MedicationFrequency.threeTimesDaily]: 'meds.freq.threeTimesDaily',
  [MedicationFrequency.weekly]: 'meds.freq.weekly',
  [MedicationFrequency.asNeeded]: 'meds.freq.asNeeded',
};

export function frequencyText(frequency: MedicationFrequency): string {
  return t(FREQ_KEY[frequency]);
}

/** Mirrors shared nextDoseDescription. */
export function nextDoseText(m: Medication, now: Date = new Date()): string | null {
  const next = nextDose(m, now);
  if (next == null) return null;

  const daysUntil = diffDays(next, now);
  if (daysUntil === 0) {
    const hour = `${next.getHours()}`.padStart(2, '0');
    const minute = `${next.getMinutes()}`.padStart(2, '0');
    return t('meds.next.today', { time: `${hour}:${minute}` });
  }
  if (daysUntil === 1) return t('meds.next.tomorrow');
  return t('meds.next.days', { count: daysUntil });
}

/** Mirrors shared todayDoseStatus. */
export function doseStatusText(m: Medication, now: Date = new Date()): string {
  if (!hasStarted(m, now)) {
    const days = daysUntilStart(m, now);
    if (days === 1) return t('meds.starts.tomorrow');
    return t('meds.starts.days', { count: days });
  }

  if (hasEnded(m, now)) {
    if (endedIncomplete(m, now)) return t('meds.ended.missed', { count: missedDoses(m, now) });
    return t('meds.ended.done');
  }

  if (m.frequency === MedicationFrequency.asNeeded) {
    const taken = dosesTakenToday(m, now);
    return taken > 0
      ? t(taken === 1 ? 'meds.takenToday.one' : 'meds.takenToday.other', { count: taken })
      : t('meds.asNeeded.take');
  }
  if (m.frequency === MedicationFrequency.once) {
    return totalDosesTaken(m) >= 1 ? t('meds.once.done') : t('meds.once.pending');
  }
  if (m.frequency === MedicationFrequency.weekly && dosesExpectedToday(m, now) === 0) {
    return t('meds.noDoseToday');
  }
  if (allDosesTakenToday(m, now)) {
    if (isBehindSchedule(m, now)) return t('meds.doneToday.missed', { count: missedDoses(m, now) });
    return t('meds.doneToday');
  }

  const remaining = dosesExpectedToday(m, now) - dosesTakenToday(m, now);
  if (isBehindSchedule(m, now)) {
    return t('meds.behind', { missed: missedDoses(m, now), remaining });
  }
  return t('meds.takenOfToday', { taken: dosesTakenToday(m, now), expected: dosesExpectedToday(m, now) });
}
