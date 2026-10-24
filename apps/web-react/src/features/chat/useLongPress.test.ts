import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { useLongPress } from './useLongPress';
import { act, renderHook } from '@testing-library/react';
import type { PointerEvent } from 'react';

const evt = (over: Partial<PointerEvent<HTMLElement>> = {}) =>
  ({ pointerType: 'touch', clientX: 0, clientY: 0, ...over }) as PointerEvent<HTMLElement>;

describe('useLongPress', () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it('fires after ms on touch', () => {
    const fn = vi.fn();
    const { result } = renderHook(() => useLongPress(fn, 450));
    act(() => result.current.onPointerDown(evt()));
    act(() => vi.advanceTimersByTime(450));
    expect(fn).toHaveBeenCalledTimes(1);
  });

  it('cancels on move > 8px', () => {
    const fn = vi.fn();
    const { result } = renderHook(() => useLongPress(fn, 450));
    act(() => result.current.onPointerDown(evt()));
    act(() => result.current.onPointerMove(evt({ clientX: 20 })));
    act(() => vi.advanceTimersByTime(600));
    expect(fn).not.toHaveBeenCalled();
  });

  it('ignores the mouse', () => {
    const fn = vi.fn();
    const { result } = renderHook(() => useLongPress(fn, 450));
    act(() => result.current.onPointerDown(evt({ pointerType: 'mouse' })));
    act(() => vi.advanceTimersByTime(600));
    expect(fn).not.toHaveBeenCalled();
  });

  it('cancels on release before ms', () => {
    const fn = vi.fn();
    const { result } = renderHook(() => useLongPress(fn, 450));
    act(() => result.current.onPointerDown(evt()));
    act(() => result.current.onPointerUp());
    act(() => vi.advanceTimersByTime(600));
    expect(fn).not.toHaveBeenCalled();
  });
});
