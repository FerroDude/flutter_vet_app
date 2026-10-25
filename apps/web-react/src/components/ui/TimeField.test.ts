import { describe, expect, it } from 'vitest';
import { timeOptions } from './TimeField';

describe('timeOptions', () => {
  it('lists the whole day in steps', () => {
    const opts = timeOptions(0, 23, 15);
    expect(opts[0]).toBe('00:00');
    expect(opts.at(-1)).toBe('23:45');
    expect(opts).toHaveLength(96);
  });

  it('ends at maxHour:00 for a bounded window', () => {
    expect(timeOptions(8, 12, 60)).toEqual(['08:00', '09:00', '10:00', '11:00', '12:00']);
    expect(timeOptions(8, 12, 15).at(-1)).toBe('12:00');
  });

  it('keeps an off-grid current value', () => {
    expect(timeOptions(8, 9, 30, '08:10')).toEqual(['08:00', '08:10', '08:30', '09:00']);
  });
});
