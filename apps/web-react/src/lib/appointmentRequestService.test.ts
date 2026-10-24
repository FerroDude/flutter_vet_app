import { describe, expect, it } from 'vitest';
import { TimePreference, type AppointmentRequest } from '@vetplus/shared';
import { defaultRequestSlot, requestWindowError } from './requestWindow';

const at = (y: number, m: number, d: number, h = 0, min = 0) => new Date(y, m, d, h, min);

const base: Pick<
  AppointmentRequest,
  'preferredDateStart' | 'preferredDateEnd' | 'timePreference'
> = {
  preferredDateStart: at(2026, 9, 20),
  preferredDateEnd: at(2026, 9, 24),
  timePreference: TimePreference.morning,
};

const req = (over: Partial<typeof base> = {}) => ({ ...base, ...over });

describe('requestWindowError', () => {
  it('accepts a morning slot inside the interval', () => {
    expect(requestWindowError(req(), at(2026, 9, 21, 9))).toBeNull();
  });

  it('accepts 12:00 for morning (inclusive end)', () => {
    expect(requestWindowError(req(), at(2026, 9, 21, 12))).toBeNull();
  });

  it('rejects 12:15 for morning', () => {
    expect(requestWindowError(req(), at(2026, 9, 21, 12, 15))).toMatch(/hora entre 8h e 12h/);
  });

  it('rejects a day before the interval', () => {
    expect(requestWindowError(req(), at(2026, 9, 19, 9))).toMatch(/dia entre/);
  });

  it('accepts the last day at 10:00', () => {
    expect(requestWindowError(req(), at(2026, 9, 24, 10))).toBeNull();
  });

  it('rejects a day after the interval', () => {
    expect(requestWindowError(req(), at(2026, 9, 25, 9))).toMatch(/dia entre/);
  });

  it('accepts 22:00 for anyTime', () => {
    expect(
      requestWindowError(req({ timePreference: TimePreference.anyTime }), at(2026, 9, 21, 22)),
    ).toBeNull();
  });
});

describe('defaultRequestSlot', () => {
  it('uses the start day at 08:00 for morning when now is before the interval', () => {
    const d = defaultRequestSlot(req(), at(2026, 9, 1, 15));
    expect(d).toEqual(at(2026, 9, 20, 8));
  });

  it('uses today when now is inside the interval', () => {
    const d = defaultRequestSlot(req(), at(2026, 9, 22, 18));
    expect(d).toEqual(at(2026, 9, 22, 8));
  });

  it('uses 09:00 for anyTime', () => {
    const d = defaultRequestSlot(req({ timePreference: TimePreference.anyTime }), at(2026, 9, 1, 15));
    expect(d).toEqual(at(2026, 9, 20, 9));
  });
});
