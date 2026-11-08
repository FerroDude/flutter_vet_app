// Browser notifications (tab-open only): permission helpers plus a per-device
// app-level mute — browsers don't let JS revoke a granted permission, so
// "off" is a flag that notifyOs checks. The actual notification send lives in
// features/chat/incomingMessage.ts (notifyOs).

const MUTED_KEY = 'vetplus.notif.muted';
const ALERTS_KEY = 'vetplus.alerts.muted';

export function alertsMuted(): boolean {
  try {
    return localStorage.getItem(ALERTS_KEY) === '1';
  } catch {
    return false;
  }
}

export function setAlertsMuted(muted: boolean): void {
  try {
    if (muted) localStorage.setItem(ALERTS_KEY, '1');
    else localStorage.removeItem(ALERTS_KEY);
  } catch {
    /* ignore */
  }
}

export function notificationsMuted(): boolean {
  try {
    return localStorage.getItem(MUTED_KEY) === '1';
  } catch {
    return false;
  }
}

export function setNotificationsMuted(muted: boolean): void {
  try {
    if (muted) localStorage.setItem(MUTED_KEY, '1');
    else localStorage.removeItem(MUTED_KEY);
  } catch {
    /* ignore */
  }
}

export function notificationsSupported(): boolean {
  return typeof Notification !== 'undefined';
}

export function notificationPermission(): NotificationPermission | 'unsupported' {
  return notificationsSupported() ? Notification.permission : 'unsupported';
}

export async function requestNotifications(): Promise<NotificationPermission | 'unsupported'> {
  if (!notificationsSupported()) return 'unsupported';
  try {
    return await Notification.requestPermission();
  } catch {
    return Notification.permission;
  }
}
