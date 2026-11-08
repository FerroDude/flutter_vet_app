import { useEffect } from 'react';
import { toast } from 'sonner';
import {
  notificationPermission,
  requestNotifications,
  setNotificationsMuted,
} from '@/lib/notifications';
import { t } from '@/i18n';

const DISMISSED_KEY = 'vetplus.notifPrompt.dismissed';
const TOAST_ID = 'notif-prompt';

/**
 * One-time notification-permission prompt. Shows a persistent toast once per
 * device until the user picks "Ativar" or "Agora não". Delayed so it doesn't
 * collide with the login screen.
 */
export function NotificationPrompt() {
  useEffect(() => {
    if (notificationPermission() !== 'default') return;
    let dismissed = false;
    try {
      dismissed = Boolean(localStorage.getItem(DISMISSED_KEY));
    } catch {
      /* storage unavailable */
    }
    if (dismissed) return;

    const dismiss = () => {
      try {
        localStorage.setItem(DISMISSED_KEY, '1');
      } catch {
        /* ignore */
      }
    };

    const timer = setTimeout(() => {
      toast(t('notif.prompt'), {
        id: TOAST_ID,
        duration: Infinity,
        action: {
          label: t('notif.enable'),
          onClick: () => {
            dismiss();
            void requestNotifications().then((p) => {
              if (p === 'granted') setNotificationsMuted(false);
            });
          },
        },
        cancel: {
          label: t('notif.notNow'),
          onClick: dismiss,
        },
        onDismiss: dismiss,
      });
    }, 1500);

    return () => clearTimeout(timer);
  }, []);

  return null;
}
