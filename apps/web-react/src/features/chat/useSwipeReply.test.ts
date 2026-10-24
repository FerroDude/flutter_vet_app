import { describe, expect, it } from 'vitest';
import { swipeOffset } from './useSwipeReply';

describe('swipeOffset', () => {
  it('is 0 for no or negative drag', () => {
    expect(swipeOffset(0)).toBe(0);
    expect(swipeOffset(-10)).toBe(0);
  });

  it('tracks 1:1 up to the trigger', () => {
    expect(swipeOffset(40)).toBe(40);
    expect(swipeOffset(60)).toBe(60);
  });

  it('damps past the trigger', () => {
    expect(swipeOffset(100)).toBe(72); // 60 + 40*0.3
  });

  it('clamps at 80', () => {
    expect(swipeOffset(140)).toBe(80);
    expect(swipeOffset(500)).toBe(80);
  });
});
