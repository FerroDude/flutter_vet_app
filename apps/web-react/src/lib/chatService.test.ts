import { describe, expect, it } from 'vitest';
import type { ChatRoom } from '@vetplus/shared';
import { clinicRoomsUnread } from './chatService';

const room = (unreadCounts: Record<string, number>): ChatRoom =>
  ({ unreadCounts }) as unknown as ChatRoom;

describe('clinicRoomsUnread', () => {
  it('sums my counters', () => {
    expect(clinicRoomsUnread([room({ me: 2 }), room({ me: 1, other: 5 })], [], 'me')).toBe(3);
  });

  it('counts each pool room with unread pool messages once', () => {
    const pool = [room({ pool: 3 }), room({ pool: 0 }), room({})];
    expect(clinicRoomsUnread([], pool, 'me')).toBe(1);
  });

  it('ignores my counter inside pool rooms', () => {
    expect(clinicRoomsUnread([], [room({ me: 4, pool: 1 })], 'me')).toBe(1);
  });
});
