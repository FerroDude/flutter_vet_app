import { describe, it, expect } from 'vitest';
import { isValidContact } from './contact';

describe('isValidContact', () => {
  it('accepts phones', () => {
    for (const v of ['910000000', '+351 912 345 678', '(21) 123-4567']) {
      expect(isValidContact(v), v).toBe(true);
    }
  });

  it('accepts emails', () => {
    expect(isValidContact('x@y.pt')).toBe(true);
    expect(isValidContact('a@b.pt')).toBe(true);
  });

  it('rejects junk', () => {
    for (const v of ['', 'abc', '12345', 'a@b', 'foo bar']) {
      expect(isValidContact(v), v).toBe(false);
    }
  });
});
