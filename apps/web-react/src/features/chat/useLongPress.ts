import { useRef, type PointerEvent } from 'react';

const MOVE_TOLERANCE = 8;

/** Long-press (touch only) → context action. Cancels on move > 8px, release or
 *  pointercancel. Vibrates briefly when it fires. */
export function useLongPress(onLongPress: () => void, ms = 450) {
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const origin = useRef({ x: 0, y: 0 });

  const cancel = () => {
    if (timer.current) {
      clearTimeout(timer.current);
      timer.current = null;
    }
  };

  const onPointerDown = (e: PointerEvent<HTMLElement>) => {
    if (e.pointerType !== 'touch') return;
    origin.current = { x: e.clientX, y: e.clientY };
    cancel();
    timer.current = setTimeout(() => {
      timer.current = null;
      navigator.vibrate?.(10);
      onLongPress();
    }, ms);
  };

  const onPointerMove = (e: PointerEvent<HTMLElement>) => {
    if (!timer.current) return;
    const dx = Math.abs(e.clientX - origin.current.x);
    const dy = Math.abs(e.clientY - origin.current.y);
    if (dx > MOVE_TOLERANCE || dy > MOVE_TOLERANCE) cancel();
  };

  return {
    onPointerDown,
    onPointerMove,
    onPointerUp: cancel,
    onPointerCancel: cancel,
  };
}
