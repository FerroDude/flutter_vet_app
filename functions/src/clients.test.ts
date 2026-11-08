import { describe, expect, it } from 'vitest';
import { normalizeEmail } from './clients.js';

describe('normalizeEmail', () => {
  it('trims and lowercases', () => {
    expect(normalizeEmail('  Ana@Gmail.COM ')).toBe('ana@gmail.com');
  });
  it('accepts a normal address', () => {
    expect(normalizeEmail('a.b+c@sub.dominio.pt')).toBe('a.b+c@sub.dominio.pt');
  });
  it.each(['', ' ', 'not-an-email', 'a@b', '@x.pt', 'a b@c.pt', 5, null, undefined])(
    'rejects %j',
    (v) => expect(normalizeEmail(v)).toBeNull(),
  );
});
