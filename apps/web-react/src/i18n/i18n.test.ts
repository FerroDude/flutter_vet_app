import { describe, expect, it } from 'vitest';
import { t } from './index';
import { pt, type TKey } from './pt';
import { en } from './en';

describe('i18n', () => {
  it('interpolates {name} placeholders', () => {
    expect(t('appointment.cancelMessage', { date: '10/10', pet: ' · Luna', reason: 'x' })).toBe(
      'Cancelei a consulta de 10/10 · Luna. Motivo: x',
    );
  });

  it('leaves missing vars untouched', () => {
    expect(t('appointment.cancelMessage', { date: '10/10' })).toContain('{pet}');
  });

  it('en has exactly the same keys as pt', () => {
    const ptKeys = Object.keys(pt).sort();
    const enKeys = Object.keys(en).sort();
    expect(enKeys).toEqual(ptKeys);
  });

  it('falls back to the key when missing', () => {
    expect(t('nonexistent.key' as TKey)).toBe('nonexistent.key');
  });
});
