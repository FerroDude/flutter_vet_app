import { afterEach, describe, expect, it, vi } from 'vitest';
import { notificationsMuted, setNotificationsMuted } from './notifications';
import { notifyOs } from '@/features/chat/incomingMessage';

class FakeNotification {
  static permission: NotificationPermission = 'granted';
  static calls = 0;
  constructor(
    public title: string,
    public options?: NotificationOptions,
  ) {
    FakeNotification.calls++;
  }
}

describe('notificationsMuted', () => {
  afterEach(() => {
    setNotificationsMuted(false);
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it('defaults to false and toggles with setNotificationsMuted', () => {
    expect(notificationsMuted()).toBe(false);
    setNotificationsMuted(true);
    expect(notificationsMuted()).toBe(true);
    setNotificationsMuted(false);
    expect(notificationsMuted()).toBe(false);
  });

  it('notifyOs skips the Notification when muted, sends when unmuted', () => {
    vi.stubGlobal('Notification', FakeNotification);
    vi.spyOn(document, 'hasFocus').mockReturnValue(false);
    const open = vi.fn();

    setNotificationsMuted(true);
    notifyOs('t', 'b', open);
    expect(FakeNotification.calls).toBe(0);

    setNotificationsMuted(false);
    notifyOs('t', 'b', open);
    expect(FakeNotification.calls).toBe(1);
  });
});
