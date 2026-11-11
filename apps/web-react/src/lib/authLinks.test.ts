import { describe, expect, it } from 'vitest';
import { appLoginUrl } from './authLinks';

describe('appLoginUrl', () => {
  it('returns the app root on this origin', () => {
    const url = appLoginUrl();
    expect(url).toBe(`${window.location.origin}${import.meta.env.BASE_URL}`);
  });

  it('adds ?email= when given', () => {
    const url = new URL(appLoginUrl('Ana+X@gmail.com'));
    expect(url.searchParams.get('email')).toBe('Ana+X@gmail.com');
  });
});
