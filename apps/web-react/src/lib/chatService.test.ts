import { describe, expect, it } from 'vitest';
import type { ChatRoom } from '@vetplus/shared';
import { clinicRoomsUnread, roomsUnreadByClinic } from './chatService';

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

describe('roomsUnreadByClinic', () => {
  it('sums unreadCounts[uid] per clinic and skips null clinicId', () => {
    const rooms = [
      { clinicId: 'a', unreadCounts: { me: 2, vet: 1 } },
      { clinicId: 'a', unreadCounts: { me: 3 } },
      { clinicId: 'b', unreadCounts: { me: 1 } },
      { clinicId: null, unreadCounts: { me: 9 } },
      { clinicId: 'c', unreadCounts: { vet: 4 } },
    ] as Parameters<typeof roomsUnreadByClinic>[0];
    expect(roomsUnreadByClinic(rooms, 'me')).toEqual({ a: 5, b: 1, c: 0 });
  });
});
