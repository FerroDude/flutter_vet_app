import { useRef, useState, type PointerEvent } from 'react';

const AXIS_DEADZONE = 8;
const TRIGGER = 60;
const MAX = 80;
const DAMPING = 0.3;

/** Drag offset for a right-swipe reply gesture: 1:1 up to 60px, damped after, max 80px. */
export function swipeOffset(dx: number): number {
  if (dx <= 0) return 0;
  const off = dx <= TRIGGER ? dx : TRIGGER + (dx - TRIGGER) * DAMPING;
  return Math.min(off, MAX);
}

/** Touch/pen swipe-right-to-reply. Mouse is ignored (hover menu covers desktop). */
export function useSwipeReply(onReply: () => void) {
  const [offset, setOffset] = useState(0);
  const st = useRef({ x: 0, y: 0, pending: false, locked: false, vib: false });

  const reset = () => {
    st.current = { x: 0, y: 0, pending: false, locked: false, vib: false };
    setOffset(0);
  };

  const onPointerDown = (e: PointerEvent<HTMLElement>) => {
    if (e.pointerType === 'mouse') return;
    st.current = { x: e.clientX, y: e.clientY, pending: true, locked: false, vib: false };
  };

  const onPointerMove = (e: PointerEvent<HTMLElement>) => {
    const s = st.current;
    if (!s.pending && !s.locked) return;
    const dx = e.clientX - s.x;
    const dy = e.clientY - s.y;
    if (!s.locked) {
      if (Math.abs(dx) < AXIS_DEADZONE && Math.abs(dy) < AXIS_DEADZONE) return;
      if (dx > 0 && Math.abs(dx) > Math.abs(dy)) {
        s.locked = true;
        s.pending = false;
        try {
          e.currentTarget.setPointerCapture(e.pointerId);
        } catch {
          /* pointer already released */
        }
      } else {
        s.pending = false; // vertical scroll wins
        return;
      }
    }
    const off = swipeOffset(dx);
    setOffset(off);
    if (off >= TRIGGER && !s.vib) {
      s.vib = true;
      navigator.vibrate?.(10);
    }
  };

  const onPointerEnd = () => {
    const fired = st.current.locked && offset >= TRIGGER;
    reset();
    if (fired) onReply();
  };

  return {
    offset,
    dragging: st.current.locked,
    handlers: {
      onPointerDown,
      onPointerMove,
      onPointerUp: onPointerEnd,
      onPointerCancel: reset,
    },
  };
}
