// Medication scheduling / adherence math.
//
// Faithful port of the computed properties from
// apps/mobile-flutter/lib/models/medication_model.dart. Each function that
// depends on the current time takes an explicit `now` argument (defaulting to
// `new Date()`) so the behavior is deterministic and unit-testable — the Dart
// code reads DateTime.now() inline.
//
// Day math uses CALENDAR days (UTC-anchored day numbers from the date's local
// Y/M/D) which avoids DST drift; this matches Dart's intent for whole-day
// differences between midnight-floored dates.

import { MedicationFrequency, MedicationStatus } from './enums';
import type { Medication, TimeOfDay } from './types';

/* ------------------------------- date helpers ------------------------------ */

function startOfDay(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

/** Calendar day number (days since epoch) for a date's local Y/M/D. */
function dayNumber(d: Date): number {
  return Math.floor(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()) / 86_400_000);
}

/** a - b in whole calendar days. */
function diffDays(a: Date, b: Date): number {
  return dayNumber(a) - dayNumber(b);
}

/** Add days while preserving the time-of-day component. */
function addDaysKeepTime(d: Date, n: number): Date {
  const r = new Date(d);
  r.setDate(r.getDate() + n);
  return r;
}

function atTime(day: Date, time: TimeOfDay): Date {
  return new Date(day.getFullYear(), day.getMonth(), day.getDate(), time.hour, time.minute);
}

function minutesOf(t: TimeOfDay): number {
  return t.hour * 60 + t.minute;
}

function sortedTimes(times: TimeOfDay[]): TimeOfDay[] {
  return [...times].sort((a, b) => minutesOf(a) - minutesOf(b));
}

function clamp(v: number, lo: number, hi: number): number {
  return Math.min(Math.max(v, lo), hi);
}

/* --------------------------------- per-day --------------------------------- */

export function dosesPerDay(frequency: MedicationFrequency): number {
  switch (frequency) {
    case MedicationFrequency.once:
    case MedicationFrequency.daily:
      return 1;
    case MedicationFrequency.twiceDaily:
      return 2;
    case MedicationFrequency.threeTimesDaily:
      return 3;
    case MedicationFrequency.weekly:
      return 1;
    case MedicationFrequency.asNeeded:
      return 0;
  }
}

/* ------------------------------ status / dates ----------------------------- */

export function isActive(m: Medication): boolean {
  return m.status === MedicationStatus.active;
}

export function isOngoing(m: Medication): boolean {
  return m.endDate == null && m.totalDays == null;
}

export function calculatedEndDate(m: Medication): Date | null {
  if (m.endDate != null) return m.endDate;
  if (m.totalDays != null) return addDaysKeepTime(m.startDate, m.totalDays - 1);
  return null;
}

export function hasStarted(m: Medication, now: Date = new Date()): boolean {
  return diffDays(m.startDate, now) <= 0;
}

export function hasEnded(m: Medication, now: Date = new Date()): boolean {
  const end = calculatedEndDate(m);
  if (end == null) return false;
  return diffDays(now, end) > 0;
}

export function isTodayInActivePeriod(m: Medication, now: Date = new Date()): boolean {
  if (!hasStarted(m, now)) return false;
  if (hasEnded(m, now)) return false;
  return true;
}

export function isDateInActivePeriod(m: Medication, date: Date): boolean {
  const start = diffDays(date, m.startDate);
  if (start < 0) return false;
  const end = calculatedEndDate(m);
  if (end != null && diffDays(date, end) > 0) return false;
  return true;
}

export function daysRemaining(m: Medication, now: Date = new Date()): number | null {
  const end = calculatedEndDate(m);
  if (end == null) return null;
  const remaining = diffDays(end, now) + 1;
  return remaining < 0 ? 0 : remaining;
}

export function currentDay(m: Medication, now: Date = new Date()): number {
  if (!hasStarted(m, now)) return 0;
  const daysSinceStart = diffDays(now, m.startDate) + 1;
  return daysSinceStart < 1 ? 1 : daysSinceStart;
}

export function daysUntilStart(m: Medication, now: Date = new Date()): number {
  const d = diffDays(m.startDate, now);
  if (d <= 0) return 0;
  return d;
}

/* ------------------------------- dose counts ------------------------------- */

export function totalExpectedDoses(m: Medication): number | null {
  if (m.totalDays == null) return null;
  if (m.frequency === MedicationFrequency.asNeeded) return null;
  if (m.frequency === MedicationFrequency.once) return 1;
  if (m.frequency === MedicationFrequency.weekly) return Math.ceil(m.totalDays / 7);
  const dpd = dosesPerDay(m.frequency);
  if (dpd === 0) return null;
  return m.totalDays * dpd;
}

export function totalDosesTaken(m: Medication): number {
  return m.doseHistory.filter((d) => d.takenAt != null).length;
}

export function totalExpectedDosesToDate(
  m: Medication,
  now: Date = new Date(),
): number | null {
  if (!hasStarted(m, now)) return 0;
  if (m.frequency === MedicationFrequency.asNeeded) return null;
  if (m.frequency === MedicationFrequency.once) {
    const first = m.doseTimes[0];
    if (first) {
      const scheduled = atTime(m.startDate, first);
      return now.getTime() > scheduled.getTime() ? 1 : 0;
    }
    return 1;
  }

  const today = startOfDay(now);
  const start = startOfDay(m.startDate);
  const end = calculatedEndDate(m);

  const effectiveEndDate =
    end != null && diffDays(today, startOfDay(end)) > 0 ? startOfDay(end) : today;

  const daysBeforeToday = diffDays(today, start);
  if (daysBeforeToday < 0) return 0;

  let totalExpected = 0;

  if (daysBeforeToday > 0) {
    if (m.frequency === MedicationFrequency.weekly) {
      for (let i = 0; i < daysBeforeToday; i += 7) totalExpected++;
    } else {
      totalExpected = daysBeforeToday * dosesPerDay(m.frequency);
    }
  }

  // For today, only count doses whose scheduled time has passed (unless the
  // course already ended before today).
  if (!(diffDays(effectiveEndDate, today) < 0)) {
    if (m.frequency === MedicationFrequency.weekly) {
      const daysSinceStart = diffDays(today, start);
      if (daysSinceStart >= 0 && daysSinceStart % 7 === 0) {
        const first = m.doseTimes[0];
        if (first) {
          const scheduled = atTime(today, first);
          if (now.getTime() > scheduled.getTime()) totalExpected++;
        } else {
          totalExpected++;
        }
      }
    } else {
      const dpd = dosesPerDay(m.frequency);
      const todayDoseTimes = m.doseTimes.slice(0, dpd);
      if (todayDoseTimes.length === 0) {
        totalExpected += dpd;
      } else {
        for (const t of todayDoseTimes) {
          const scheduled = atTime(today, t);
          if (now.getTime() > scheduled.getTime()) totalExpected++;
        }
      }
    }
  }

  return totalExpected;
}

export function missedDoses(m: Medication, now: Date = new Date()): number {
  const expected = totalExpectedDosesToDate(m, now);
  if (expected == null) return 0;
  return clamp(expected - totalDosesTaken(m), 0, expected);
}

export function isBehindSchedule(m: Medication, now: Date = new Date()): boolean {
  return missedDoses(m, now) > 0;
}

export function adherenceRate(m: Medication, now: Date = new Date()): number | null {
  const expected = totalExpectedDosesToDate(m, now);
  if (expected == null || expected === 0) return null;
  return clamp(totalDosesTaken(m) / expected, 0, 1);
}

export function endedIncomplete(m: Medication, now: Date = new Date()): boolean {
  if (!hasEnded(m, now)) return false;
  const expected = totalExpectedDoses(m);
  if (expected == null) return false;
  return totalDosesTaken(m) < expected;
}

export function progress(m: Medication, now: Date = new Date()): number | null {
  if (m.totalDays == null) return null;
  if (!hasStarted(m, now)) return 0;

  if (m.frequency === MedicationFrequency.asNeeded) {
    const daysPassed = diffDays(now, m.startDate);
    if (daysPassed < 0) return 0;
    const p = daysPassed / m.totalDays;
    return p > 1 ? 1 : p;
  }

  const expected = totalExpectedDoses(m);
  if (expected == null || expected === 0) return 0;
  const taken = totalDosesTaken(m);
  const p = taken / expected;
  return p > 1 ? 1 : p;
}

/* ------------------------------- per-date sums ----------------------------- */

export function isDoseScheduledOnDate(m: Medication, date: Date): boolean {
  if (m.status !== MedicationStatus.active) return false;
  if (!isDateInActivePeriod(m, date)) return false;
  if (m.frequency === MedicationFrequency.asNeeded) return false;
  if (m.frequency === MedicationFrequency.once) {
    return diffDays(date, m.startDate) === 0 && totalDosesTaken(m) < 1;
  }
  if (m.frequency === MedicationFrequency.weekly) {
    const daysSinceStart = diffDays(date, m.startDate);
    return daysSinceStart >= 0 && daysSinceStart % 7 === 0;
  }
  return true;
}

export function dosesExpectedOnDate(m: Medication, date: Date): number {
  if (!isDoseScheduledOnDate(m, date)) return 0;
  switch (m.frequency) {
    case MedicationFrequency.once:
    case MedicationFrequency.daily:
      return 1;
    case MedicationFrequency.twiceDaily:
      return 2;
    case MedicationFrequency.threeTimesDaily:
      return 3;
    case MedicationFrequency.weekly:
      return 1;
    case MedicationFrequency.asNeeded:
      return 0;
  }
}

export function dosesTakenOnDate(m: Medication, date: Date): number {
  const dayStart = startOfDay(date).getTime();
  const dayEnd = dayStart + 86_400_000;
  return m.doseHistory.filter((log) => {
    if (log.takenAt == null) return false;
    const t = log.takenAt.getTime();
    return t >= dayStart && t < dayEnd;
  }).length;
}

export function dosesTakenToday(m: Medication, now: Date = new Date()): number {
  return dosesTakenOnDate(m, now);
}

export function dosesExpectedToday(m: Medication, now: Date = new Date()): number {
  if (!isTodayInActivePeriod(m, now)) return 0;
  switch (m.frequency) {
    case MedicationFrequency.once:
    case MedicationFrequency.daily:
      return 1;
    case MedicationFrequency.twiceDaily:
      return 2;
    case MedicationFrequency.threeTimesDaily:
      return 3;
    case MedicationFrequency.weekly: {
      const daysSinceStart = diffDays(now, m.startDate);
      return daysSinceStart % 7 === 0 ? 1 : 0;
    }
    case MedicationFrequency.asNeeded:
      return 0;
  }
}

export function allDosesTakenToday(m: Medication, now: Date = new Date()): boolean {
  if (!isTodayInActivePeriod(m, now)) return true;
  if (m.frequency === MedicationFrequency.asNeeded) return false;
  if (m.frequency === MedicationFrequency.once) return totalDosesTaken(m) >= 1;
  if (dosesExpectedToday(m, now) === 0) return true;
  return dosesTakenToday(m, now) >= dosesExpectedToday(m, now);
}

export function dosesRemainingToday(m: Medication, now: Date = new Date()): number {
  if (!isTodayInActivePeriod(m, now)) return 0;
  if (m.frequency === MedicationFrequency.asNeeded) return 999;
  if (m.frequency === MedicationFrequency.once) return totalDosesTaken(m) >= 1 ? 0 : 1;
  const remaining = dosesExpectedToday(m, now) - dosesTakenToday(m, now);
  return remaining < 0 ? 0 : remaining;
}

/* --------------------------------- next dose ------------------------------- */

export function nextDoseToday(m: Medication, now: Date = new Date()): Date | null {
  const today = startOfDay(now);
  for (const time of m.doseTimes) {
    const doseDateTime = atTime(today, time);
    if (doseDateTime.getTime() > now.getTime()) return doseDateTime;
  }
  return null;
}

export function nextDose(m: Medication, now: Date = new Date()): Date | null {
  if (m.status !== MedicationStatus.active) return null;
  if (m.frequency === MedicationFrequency.asNeeded) return null;

  const today = startOfDay(now);
  const startDay = startOfDay(m.startDate);

  const end = calculatedEndDate(m);
  if (end != null && now.getTime() > end.getTime()) return null;

  const times = sortedTimes(m.doseTimes);
  const firstTime = times[0];
  if (!firstTime) return null;
  const endDay = end != null ? startOfDay(end) : null;

  if (!hasStarted(m, now)) {
    return atTime(startDay, firstTime);
  }

  if (m.frequency === MedicationFrequency.once) {
    if (totalDosesTaken(m) >= 1) return null;
    for (const time of times) {
      const doseDateTime = atTime(today, time);
      if (doseDateTime.getTime() > now.getTime()) return doseDateTime;
    }
    const tomorrow = addDaysKeepTime(today, 1);
    if (endDay != null && diffDays(tomorrow, endDay) > 0) return null;
    return atTime(tomorrow, firstTime);
  }

  if (m.frequency === MedicationFrequency.weekly) {
    const daysSinceStart = diffDays(today, startDay);
    const daysUntilNextDose = (7 - (daysSinceStart % 7)) % 7;

    if (daysUntilNextDose === 0 || daysSinceStart % 7 === 0) {
      if (!allDosesTakenToday(m, now)) {
        for (const time of times) {
          const doseDateTime = atTime(today, time);
          if (doseDateTime.getTime() > now.getTime()) return doseDateTime;
        }
      }
      const nextDoseDay = addDaysKeepTime(today, 7);
      if (endDay != null && diffDays(nextDoseDay, endDay) > 0) return null;
      return atTime(nextDoseDay, firstTime);
    } else {
      const nextDoseDay = addDaysKeepTime(today, daysUntilNextDose);
      if (endDay != null && diffDays(nextDoseDay, endDay) > 0) return null;
      return atTime(nextDoseDay, firstTime);
    }
  }

  // Daily / twiceDaily / threeTimesDaily
  if (isTodayInActivePeriod(m, now) && !allDosesTakenToday(m, now)) {
    for (const time of times) {
      const doseDateTime = atTime(today, time);
      if (doseDateTime.getTime() > now.getTime()) return doseDateTime;
    }
  }

  const tomorrow = addDaysKeepTime(today, 1);
  if (endDay != null && diffDays(tomorrow, endDay) > 0) return null;
  return atTime(tomorrow, firstTime);
}

export function nextDoseDescription(m: Medication, now: Date = new Date()): string | null {
  const next = nextDose(m, now);
  if (next == null) return null;

  const daysUntil = diffDays(next, now);

  if (daysUntil === 0) {
    const hour = `${next.getHours()}`.padStart(2, '0');
    const minute = `${next.getMinutes()}`.padStart(2, '0');
    return `Próxima: hoje às ${hour}:${minute}`;
  } else if (daysUntil === 1) {
    return 'Próxima: amanhã';
  }
  return `Próxima: daqui a ${daysUntil} dias`;
}

/* ------------------------------- display / edit ---------------------------- */

export function frequencyDisplay(frequency: MedicationFrequency): string {
  switch (frequency) {
    case MedicationFrequency.once:
      return 'Uma vez';
    case MedicationFrequency.daily:
      return 'Uma vez por dia';
    case MedicationFrequency.twiceDaily:
      return 'Duas vezes por dia';
    case MedicationFrequency.threeTimesDaily:
      return 'Três vezes por dia';
    case MedicationFrequency.weekly:
      return 'Semanal';
    case MedicationFrequency.asNeeded:
      return 'Quando necessário';
  }
}

export function canBeExtended(m: Medication, now: Date = new Date()): boolean {
  if (m.status === MedicationStatus.discontinued) return false;
  if (m.frequency === MedicationFrequency.once) return false;
  return m.totalDays != null || hasEnded(m, now) || m.status === MedicationStatus.completed;
}

/** Returns the patch to apply (new totalDays/status/updatedAt). Mirrors extendBy. */
export function extendBy(
  m: Medication,
  additionalDays: number,
  now: Date = new Date(),
): { totalDays: number; status: MedicationStatus; updatedAt: Date } {
  const today = startOfDay(now);
  let newTotalDays: number;
  if (hasEnded(m, now)) {
    const newEndDate = addDaysKeepTime(today, additionalDays - 1);
    newTotalDays = diffDays(newEndDate, m.startDate) + 1;
  } else {
    newTotalDays = (m.totalDays ?? 0) + additionalDays;
  }
  return { totalDays: newTotalDays, status: MedicationStatus.active, updatedAt: now };
}

export function todayDoseStatus(m: Medication, now: Date = new Date()): string {
  if (!hasStarted(m, now)) {
    const days = daysUntilStart(m, now);
    if (days === 1) return 'Começa amanhã';
    return `Começa daqui a ${days} dias`;
  }

  if (hasEnded(m, now)) {
    if (endedIncomplete(m, now)) return `Tratamento terminou · ${missedDoses(m, now)} em falta`;
    return 'Tratamento concluído';
  }

  if (m.frequency === MedicationFrequency.asNeeded) {
    const taken = dosesTakenToday(m, now);
    return taken > 0 ? `${taken} ${taken === 1 ? 'dose tomada' : 'doses tomadas'} hoje` : 'Tomar quando necessário';
  }
  if (m.frequency === MedicationFrequency.once) {
    return totalDosesTaken(m) >= 1 ? 'Concluída' : 'Ainda não tomada';
  }
  if (m.frequency === MedicationFrequency.weekly && dosesExpectedToday(m, now) === 0) {
    return 'Sem dose hoje';
  }
  if (allDosesTakenToday(m, now)) {
    if (isBehindSchedule(m, now)) return `Feito hoje · ${missedDoses(m, now)} em falta no total`;
    return 'Doses de hoje tomadas';
  }

  const remaining = dosesExpectedToday(m, now) - dosesTakenToday(m, now);
  if (isBehindSchedule(m, now)) return `${missedDoses(m, now)} em falta · ${remaining} para hoje`;
  return `${dosesTakenToday(m, now)} de ${dosesExpectedToday(m, now)} tomadas hoje`;
}
