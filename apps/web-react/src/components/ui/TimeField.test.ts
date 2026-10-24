import { describe, expect, it } from 'vitest';
import { minuteOptions } from './TimeField';

describe('minuteOptions', () => {
  it('lists minutes by step', () => {
    expect(minuteOptions(9, 23, 15)).toEqual([0, 15, 30, 45]);
  });

  it('only allows :00 at a bounded maxHour', () => {
    expect(minuteOptions(12, 12, 15)).toEqual([0]);
  });

  it('allows all stepped minutes when maxHour is 23', () => {
    expect(minuteOptions(23, 23, 15)).toEqual([0, 15, 30, 45]);
  });

  it('keeps an off-grid current value', () => {
    expect(minuteOptions(8, 23, 15, 10)).toEqual([0, 10, 15, 30, 45]);
  });
});
