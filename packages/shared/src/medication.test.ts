import { describe, it, expect } from 'vitest';
import { MedicationFrequency, MedicationStatus } from './enums';
import type { Medication, DoseLog, TimeOfDay } from './types';
import {
  dosesPerDay,
  calculatedEndDate,
  hasStarted,
  hasEnded,
  isTodayInActivePeriod,
  daysRemaining,
  currentDay,
  daysUntilStart,
  totalExpectedDoses,
  totalDosesTaken,
  totalExpectedDosesToDate,
  missedDoses,
  isBehindSchedule,
  adherenceRate,
  endedIncomplete,
  progress,
  isDoseScheduledOnDate,
  dosesExpectedOnDate,
  dosesTakenOnDate,
  dosesExpectedToday,
  dosesTakenToday,
  allDosesTakenToday,
  dosesRemainingToday,
  nextDose,
  nextDoseDescription,
  frequencyDisplay,
  canBeExtended,
  extendBy,
  todayDoseStatus,
} from './medication';

const T8: TimeOfDay = { hour: 8, minute: 0 };

function med(partial: Partial<Medication> = {}): Medication {
  return {
    id: 'm',
    petId: 'p',
    ownerId: 'o',
    name: 'Med',
    dosage: '1 pill',
    instructions: null,
    frequency: MedicationFrequency.daily,
    doseTimes: [T8],
    startDate: new Date(2026, 0, 1, 0, 0),
    endDate: null,
    totalDays: null,
    status: MedicationStatus.active,
    trackDoses: true,
    doseHistory: [],
    remindersEnabled: true,
    createdAt: new Date(2026, 0, 1),
    updatedAt: new Date(2026, 0, 1),
    prescribedByVetId: null,
    prescribedByVetName: null,
    ...partial,
  };
}

function takenAt(d: Date): DoseLog {
  return { id: Math.random().toString(), scheduledTime: d, takenAt: d, skipped: false, notes: null };
}

describe('dosesPerDay', () => {
  it('maps each frequency', () => {
    expect(dosesPerDay(MedicationFrequency.once)).toBe(1);
    expect(dosesPerDay(MedicationFrequency.daily)).toBe(1);
    expect(dosesPerDay(MedicationFrequency.twiceDaily)).toBe(2);
    expect(dosesPerDay(MedicationFrequency.threeTimesDaily)).toBe(3);
    expect(dosesPerDay(MedicationFrequency.weekly)).toBe(1);
    expect(dosesPerDay(MedicationFrequency.asNeeded)).toBe(0);
  });
});

describe('dates', () => {
  it('calculatedEndDate from totalDays', () => {
    const m = med({ totalDays: 7 }); // Jan 1 .. Jan 7
    expect(calculatedEndDate(m)?.getDate()).toBe(7);
  });

  it('explicit endDate wins', () => {
    const end = new Date(2026, 0, 10);
    expect(calculatedEndDate(med({ endDate: end }))).toBe(end);
  });

  it('hasStarted / hasEnded', () => {
    const m = med({ totalDays: 7 });
    expect(hasStarted(m, new Date(2025, 11, 31))).toBe(false);
    expect(hasStarted(m, new Date(2026, 0, 1, 12))).toBe(true);
    expect(hasEnded(m, new Date(2026, 0, 5))).toBe(false);
    expect(hasEnded(m, new Date(2026, 0, 8))).toBe(true);
    expect(isTodayInActivePeriod(m, new Date(2026, 0, 5))).toBe(true);
  });

  it('daysRemaining / currentDay / daysUntilStart', () => {
    const m = med({ totalDays: 7 });
    expect(daysRemaining(m, new Date(2026, 0, 3, 9))).toBe(5); // Jan3..Jan7 inclusive
    expect(currentDay(m, new Date(2026, 0, 3, 9))).toBe(3);
    expect(daysUntilStart(med({ startDate: new Date(2026, 0, 5) }), new Date(2026, 0, 1))).toBe(4);
  });
});

describe('expected dose counts', () => {
  it('totalExpectedDoses by frequency', () => {
    expect(totalExpectedDoses(med({ totalDays: 7, frequency: MedicationFrequency.daily }))).toBe(7);
    expect(totalExpectedDoses(med({ totalDays: 7, frequency: MedicationFrequency.twiceDaily }))).toBe(14);
    expect(totalExpectedDoses(med({ totalDays: 14, frequency: MedicationFrequency.weekly }))).toBe(2);
    expect(totalExpectedDoses(med({ totalDays: 7, frequency: MedicationFrequency.once }))).toBe(1);
    expect(totalExpectedDoses(med({ totalDays: 7, frequency: MedicationFrequency.asNeeded }))).toBeNull();
    expect(totalExpectedDoses(med({ totalDays: null }))).toBeNull();
  });

  it('totalExpectedDosesToDate counts past days plus passed times today', () => {
    const m = med({ totalDays: 7 }); // daily 08:00
    expect(totalExpectedDosesToDate(m, new Date(2026, 0, 3, 9))).toBe(3); // 2 past + today passed
    expect(totalExpectedDosesToDate(m, new Date(2026, 0, 3, 7))).toBe(2); // today's 08:00 not reached
    expect(totalExpectedDosesToDate(m, new Date(2025, 11, 31))).toBe(0); // not started
  });

  it('twiceDaily counts both today times that passed', () => {
    const m = med({ totalDays: 7, frequency: MedicationFrequency.twiceDaily, doseTimes: [{ hour: 8, minute: 0 }, { hour: 20, minute: 0 }] });
    expect(totalExpectedDosesToDate(m, new Date(2026, 0, 1, 9))).toBe(1); // only 08:00 passed
    expect(totalExpectedDosesToDate(m, new Date(2026, 0, 1, 21))).toBe(2); // both passed
  });
});

describe('adherence', () => {
  it('missed / behind / adherence', () => {
    const m = med({ totalDays: 7, doseHistory: [takenAt(new Date(2026, 0, 1, 8))] });
    const now = new Date(2026, 0, 3, 9); // expected to date = 3
    expect(totalDosesTaken(m)).toBe(1);
    expect(missedDoses(m, now)).toBe(2);
    expect(isBehindSchedule(m, now)).toBe(true);
    expect(adherenceRate(m, now)).toBeCloseTo(1 / 3, 5);
  });

  it('progress = taken / total expected', () => {
    const m = med({ totalDays: 7, doseHistory: [takenAt(new Date(2026, 0, 1, 8)), takenAt(new Date(2026, 0, 2, 8)), takenAt(new Date(2026, 0, 3, 8))] });
    expect(progress(m, new Date(2026, 0, 3, 9))).toBeCloseTo(3 / 7, 5);
    expect(progress(med({ totalDays: null }))).toBeNull();
  });

  it('endedIncomplete', () => {
    const m = med({ totalDays: 7, doseHistory: [takenAt(new Date(2026, 0, 1, 8))] });
    expect(endedIncomplete(m, new Date(2026, 0, 10))).toBe(true);
  });
});

describe('per-date', () => {
  it('weekly scheduled every 7 days', () => {
    const m = med({ totalDays: 21, frequency: MedicationFrequency.weekly });
    expect(isDoseScheduledOnDate(m, new Date(2026, 0, 1))).toBe(true);
    expect(isDoseScheduledOnDate(m, new Date(2026, 0, 2))).toBe(false);
    expect(isDoseScheduledOnDate(m, new Date(2026, 0, 8))).toBe(true);
    expect(dosesExpectedOnDate(m, new Date(2026, 0, 8))).toBe(1);
  });

  it('dosesTakenOnDate respects day boundaries', () => {
    const m = med({ doseHistory: [takenAt(new Date(2026, 0, 2, 23, 59)), takenAt(new Date(2026, 0, 3, 0, 1))] });
    expect(dosesTakenOnDate(m, new Date(2026, 0, 2))).toBe(1);
    expect(dosesTakenOnDate(m, new Date(2026, 0, 3))).toBe(1);
  });

  it('today expectations / remaining', () => {
    const m = med({ totalDays: 7, frequency: MedicationFrequency.twiceDaily, doseTimes: [{ hour: 8, minute: 0 }, { hour: 20, minute: 0 }] });
    const now = new Date(2026, 0, 3, 12);
    expect(dosesExpectedToday(m, now)).toBe(2);
    expect(dosesTakenToday(m, now)).toBe(0);
    expect(allDosesTakenToday(m, now)).toBe(false);
    expect(dosesRemainingToday(m, now)).toBe(2);
  });

  it('once taken => all taken today', () => {
    const m = med({ frequency: MedicationFrequency.once, doseHistory: [takenAt(new Date(2026, 0, 1, 8))] });
    expect(allDosesTakenToday(m, new Date(2026, 0, 1, 9))).toBe(true);
  });
});

describe('nextDose', () => {
  it('daily returns today if time not passed, else tomorrow', () => {
    const m = med({ totalDays: 7 });
    const early = nextDose(m, new Date(2026, 0, 3, 7));
    expect(early?.getDate()).toBe(3);
    expect(early?.getHours()).toBe(8);
    const late = nextDose(m, new Date(2026, 0, 3, 9));
    expect(late?.getDate()).toBe(4);
  });

  it('not started => first dose on start day', () => {
    const m = med({ totalDays: 7, startDate: new Date(2026, 0, 5, 0, 0) });
    const next = nextDose(m, new Date(2026, 0, 1, 12));
    expect(next?.getDate()).toBe(5);
    expect(next?.getHours()).toBe(8);
  });

  it('asNeeded / paused => null', () => {
    expect(nextDose(med({ frequency: MedicationFrequency.asNeeded }))).toBeNull();
    expect(nextDose(med({ status: MedicationStatus.paused }))).toBeNull();
  });

  it('once already taken => null', () => {
    const m = med({ frequency: MedicationFrequency.once, doseHistory: [takenAt(new Date(2026, 0, 1, 8))] });
    expect(nextDose(m, new Date(2026, 0, 1, 9))).toBeNull();
  });

  it('nextDoseDescription formatting', () => {
    const m = med({ totalDays: 7 });
    expect(nextDoseDescription(m, new Date(2026, 0, 3, 7))).toBe('Próxima: hoje às 08:00');
    expect(nextDoseDescription(m, new Date(2026, 0, 3, 9))).toBe('Próxima: amanhã');
  });
});

describe('display + extend', () => {
  it('frequencyDisplay', () => {
    expect(frequencyDisplay(MedicationFrequency.twiceDaily)).toBe('Duas vezes por dia');
    expect(frequencyDisplay(MedicationFrequency.asNeeded)).toBe('Quando necessário');
  });

  it('canBeExtended', () => {
    expect(canBeExtended(med({ totalDays: 7 }))).toBe(true);
    expect(canBeExtended(med({ frequency: MedicationFrequency.once, totalDays: 1 }))).toBe(false);
    expect(canBeExtended(med({ status: MedicationStatus.discontinued, totalDays: 7 }))).toBe(false);
  });

  it('extendBy active adds days', () => {
    const m = med({ totalDays: 7 });
    const patch = extendBy(m, 7, new Date(2026, 0, 3));
    expect(patch.totalDays).toBe(14);
    expect(patch.status).toBe(MedicationStatus.active);
  });

  it('extendBy after end extends from today', () => {
    const m = med({ totalDays: 7, startDate: new Date(2026, 0, 1) }); // ends Jan 7
    const patch = extendBy(m, 3, new Date(2026, 0, 10)); // today..today+2 = Jan10..Jan12
    // newTotalDays = diffDays(Jan12, Jan1) + 1 = 11 + 1 = 12
    expect(patch.totalDays).toBe(12);
  });
});

describe('todayDoseStatus', () => {
  it('not started', () => {
    const m = med({ totalDays: 7, startDate: new Date(2026, 0, 5) });
    expect(todayDoseStatus(m, new Date(2026, 0, 3))).toBe('Começa daqui a 2 dias');
    expect(todayDoseStatus(m, new Date(2026, 0, 4))).toBe('Começa amanhã');
  });

  it('completed course', () => {
    const m = med({
      totalDays: 1,
      doseHistory: [takenAt(new Date(2026, 0, 1, 8))],
    });
    expect(todayDoseStatus(m, new Date(2026, 0, 5))).toBe('Tratamento concluído');
  });

  it('active progress line', () => {
    const m = med({ totalDays: 7, frequency: MedicationFrequency.twiceDaily, doseTimes: [{ hour: 8, minute: 0 }, { hour: 20, minute: 0 }], doseHistory: [takenAt(new Date(2026, 0, 1, 8))] });
    // now Jan 1 09:00: expected-to-date = 1, taken = 1 => not behind, 1 of 2 taken today
    expect(todayDoseStatus(m, new Date(2026, 0, 1, 9))).toBe('1 de 2 tomadas hoje');
  });
});
