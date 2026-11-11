import { describe, expect, it } from 'vitest';
import { matchesQuery } from './textMatch';

describe('matchesQuery', () => {
  it('matches case-insensitively', () => {
    expect(matchesQuery('ana', 'Ana Silva')).toBe(true);
  });
  it('matches accent-insensitively', () => {
    expect(matchesQuery('joao', 'João Pedro')).toBe(true);
    expect(matchesQuery('josé', 'Jose')).toBe(true);
  });
  it('empty query matches everything', () => {
    expect(matchesQuery('  ', 'x')).toBe(true);
  });
  it('rejects non-substrings', () => {
    expect(matchesQuery('maria', 'Ana Silva')).toBe(false);
  });
});
