// Web push (FCM) client helpers. Mirrors the mobile push setup: obtain an FCM
// token and store it on `users/{uid}.fcmToken` — the existing Cloud Functions
// (sendPushToUser / sendPushToClinicStaff / appointment triggers) deliver to
// whatever token is stored, so no server change is needed.
//
// Background notifications are handled by public/firebase-messaging-sw.js.
// Foreground messages are surfaced as toasts via initForegroundMessages().

import { getMessaging, getToken, onMessage, isSupported, type Messaging } from 'firebase/messaging';
import { doc, updateDoc } from 'firebase/firestore';
import { toast } from 'sonner';
import { app, db } from './firebase';
import { firebaseEnv } from './env';

let messagingPromise: Promise<Messaging | null> | null = null;
let foregroundBound = false;

/** Resolve a Messaging instance, or null if the browser can't support FCM. */
async function getMessagingIfSupported(): Promise<Messaging | null> {
  if (!messagingPromise) {
    messagingPromise = (async () => {
      try {
        if (!(await isSupported())) return null;
        if (!('serviceWorker' in navigator)) return null;
        return getMessaging(app);
      } catch {
        return null;
      }
    })();
  }
  return messagingPromise;
}

export async function isPushSupported(): Promise<boolean> {
  return (await getMessagingIfSupported()) !== null;
}

export function pushPermission(): NotificationPermission | 'unsupported' {
  if (typeof Notification === 'undefined') return 'unsupported';
  return Notification.permission;
}

/** Register the FCM service worker, passing the (public) web config as params. */
async function registerSW(): Promise<ServiceWorkerRegistration | undefined> {
  if (!('serviceWorker' in navigator)) return undefined;
  const params = new URLSearchParams({
    apiKey: firebaseEnv.apiKey,
    authDomain: firebaseEnv.authDomain,
    projectId: firebaseEnv.projectId,
    storageBucket: firebaseEnv.storageBucket,
    messagingSenderId: firebaseEnv.messagingSenderId,
    appId: firebaseEnv.appId,
  });
  return navigator.serviceWorker.register(`/firebase-messaging-sw.js?${params.toString()}`, {
    scope: '/',
  });
}

async function saveToken(uid: string, token: string | null): Promise<void> {
  await updateDoc(doc(db, 'users', uid), {
    fcmToken: token,
    updatedAt: Date.now(),
  });
}

/**
 * Request permission (if needed), obtain a token, and store it on the user.
 * Returns the token, or null if unsupported / denied / failed.
 */
export async function enablePush(uid: string): Promise<string | null> {
  const messaging = await getMessagingIfSupported();
  if (!messaging || !firebaseEnv.vapidKey) return null;

  if (typeof Notification !== 'undefined' && Notification.permission === 'default') {
    const perm = await Notification.requestPermission();
    if (perm !== 'granted') return null;
  }
  if (typeof Notification !== 'undefined' && Notification.permission !== 'granted') {
    return null;
  }

  const registration = await registerSW();
  const token = await getToken(messaging, {
    vapidKey: firebaseEnv.vapidKey,
    serviceWorkerRegistration: registration,
  });
  if (token) await saveToken(uid, token);
  return token ?? null;
}

/** Clear the stored token so this device stops receiving pushes. */
export async function disablePush(uid: string): Promise<void> {
  await saveToken(uid, null);
}

/**
 * Silently refresh + persist the token if permission is already granted.
 * Safe to call on every authenticated load.
 */
export async function syncPushToken(uid: string): Promise<void> {
  if (typeof Notification === 'undefined' || Notification.permission !== 'granted') return;
  try {
    await enablePush(uid);
  } catch {
    /* non-fatal */
  }
}

/** Show a toast for messages received while the app is in the foreground. */
export async function initForegroundMessages(): Promise<void> {
  if (foregroundBound) return;
  const messaging = await getMessagingIfSupported();
  if (!messaging) return;
  foregroundBound = true;
  onMessage(messaging, (payload) => {
    const title = payload.notification?.title;
    const body = payload.notification?.body;
    if (title || body) {
      toast(title ?? 'New notification', { description: body });
    }
  });
}
