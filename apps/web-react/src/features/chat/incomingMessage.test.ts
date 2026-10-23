import { describe, expect, it } from 'vitest';
import { incomingBody, incomingNotice, incomingTitle } from './incomingMessage';

describe('incomingNotice', () => {
  const base = {
    prevUnread: 0,
    nextUnread: 1,
    senderId: 'vet',
    uid: 'client',
    roomId: 'room-1',
    activeRoomId: null as string | null,
  };

  it('notifies the receiver when unread rises', () => {
    expect(incomingNotice(base)).toEqual({ show: true, count: 1 });
  });

  it('stays quiet for the sender', () => {
    expect(incomingNotice({ ...base, senderId: 'client', uid: 'client' }).show).toBe(false);
  });

  it('stays quiet when that chat is already open', () => {
    expect(incomingNotice({ ...base, activeRoomId: 'room-1' }).show).toBe(false);
  });

  it('stays quiet when unread does not rise', () => {
    expect(incomingNotice({ ...base, prevUnread: 2, nextUnread: 2 }).show).toBe(false);
    expect(incomingNotice({ ...base, prevUnread: 2, nextUnread: 0 }).show).toBe(false);
  });

  it('counts a burst as one notice', () => {
    expect(incomingNotice({ ...base, prevUnread: 1, nextUnread: 4 })).toEqual({
      show: true,
      count: 3,
    });
    expect(incomingTitle(1)).toBe('Mensagem nova');
    expect(incomingTitle(3)).toBe('3 mensagens novas');
  });

  it('builds a short preview', () => {
    expect(incomingBody('Ana', 'Olá')).toBe('Ana: Olá');
    expect(incomingBody('Ana', 'x'.repeat(90)).length).toBeLessThanOrEqual(80 + 'Ana: '.length);
  });
});
