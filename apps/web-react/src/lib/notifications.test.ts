import { afterEach, describe, expect, it, vi } from 'vitest';
import {
  alertsMuted,
  notificationsMuted,
  setAlertsMuted,
  setNotificationsMuted,
} from './notifications';
import { notifyOs, showAlert } from '@/features/chat/incomingMessage';

vi.mock('sonner', () => ({ toast: vi.fn() }));
import { toast } from 'sonner';

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
    setAlertsMuted(false);
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
    vi.clearAllMocks();
    FakeNotification.calls = 0;
  });

  it('defaults to false and toggles with setNotificationsMuted', () => {
    expect(notificationsMuted()).toBe(false);
    setNotificationsMuted(true);
    expect(notificationsMuted()).toBe(true);
    setNotificationsMuted(false);
    expect(notificationsMuted()).toBe(false);
  });

  it('alertsMuted defaults to false and toggles', () => {
    expect(alertsMuted()).toBe(false);
    setAlertsMuted(true);
    expect(alertsMuted()).toBe(true);
    setAlertsMuted(false);
    expect(alertsMuted()).toBe(false);
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

  it('showAlert hides the sonner toast when alerts are muted but still notifies the OS', () => {
    vi.stubGlobal('Notification', FakeNotification);
    vi.spyOn(document, 'hasFocus').mockReturnValue(false);
    const open = vi.fn();

    setAlertsMuted(true);
    showAlert({ id: 'x1', title: 'T', description: 'D', open });
    expect(toast).not.toHaveBeenCalled();
    expect(FakeNotification.calls).toBe(1);
  });

  it('showAlert calls sonner toast with the given id/title when unmuted', () => {
    vi.stubGlobal('Notification', FakeNotification);
    vi.spyOn(document, 'hasFocus').mockReturnValue(false);
    const open = vi.fn();

    showAlert({ id: 'x2', title: 'T2', description: 'D2', open });
    expect(toast).toHaveBeenCalledWith(
      'T2',
      expect.objectContaining({ id: 'x2', description: 'D2', duration: 15000 }),
    );
  });
});
