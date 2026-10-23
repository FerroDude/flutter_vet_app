/* Firebase Cloud Messaging service worker (background notifications).
 *
 * Uses the compat builds because service workers can't easily load the modular
 * ESM SDK. The Firebase web config is passed as query params when the page
 * registers this worker (see src/lib/messaging.ts) — these values are public
 * (same as the bundled app config), so this avoids duplicating them here.
 *
 * We intentionally do NOT define onBackgroundMessage: the Cloud Functions send a
 * `notification` payload, which FCM displays automatically. Defining a handler
 * here too would show the notification twice. We only add a click handler so
 * tapping a notification focuses/opens the app.
 */
/* global importScripts, firebase, clients */

importScripts('https://www.gstatic.com/firebasejs/11.1.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.1.0/firebase-messaging-compat.js');

const params = new URLSearchParams(self.location.search);
const config = {
  apiKey: params.get('apiKey'),
  authDomain: params.get('authDomain'),
  projectId: params.get('projectId'),
  storageBucket: params.get('storageBucket'),
  messagingSenderId: params.get('messagingSenderId'),
  appId: params.get('appId'),
};

if (config.apiKey && config.projectId && config.appId) {
  firebase.initializeApp(config);
  // Initializing messaging in the SW enables automatic display of background
  // `notification` payloads.
  firebase.messaging();
}

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      for (const client of list) {
        if ('focus' in client) return client.focus();
      }
      if (clients.openWindow) return clients.openWindow(self.registration.scope);
      return undefined;
    }),
  );
});
