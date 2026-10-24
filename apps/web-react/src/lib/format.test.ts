import { describe, expect, it } from 'vitest';
import { eventTitle } from './format';

// Test env defaults to lang 'pt': stored en titles render in pt, stored pt
// titles stay as-is, custom titles pass through.
describe('eventTitle', () => {
  it('re-translates an en default title into the current language', () => {
    expect(eventTitle('Appointment — Rex')).toBe('Consulta — Rex');
  });

  it('re-translates the bare default name', () => {
    expect(eventTitle('Appointment')).toBe('Consulta');
  });

  it('keeps pt titles and custom titles unchanged', () => {
    expect(eventTitle('Consulta — Luna')).toBe('Consulta — Luna');
    expect(eventTitle('Banho')).toBe('Banho');
    expect(eventTitle('Annual check-up')).toBe('Annual check-up');
  });
});
