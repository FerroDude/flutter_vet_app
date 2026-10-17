// Firebase initialization for the web app.
//
// - Primary app: the normal authenticated session.
// - Secondary app: a second initialized app instance used to create invited
//   staff/admin Auth accounts WITHOUT disturbing the current admin's session
//   (mirrors the Flutter "secondary" app pattern in UserProvider). Auth on the
//   secondary app is created lazily when needed.

import { initializeApp, getApps, getApp, type FirebaseApp } from 'firebase/app';
import { getAuth, type Auth } from 'firebase/auth';
import { getFirestore, type Firestore } from 'firebase/firestore';
import { getStorage, type FirebaseStorage } from 'firebase/storage';
import { firebaseEnv, isFirebaseConfigured } from './env';

// Backend: Firestore (data) + Storage (media). No Realtime Database — the mobile
// app only wired RTDB for chat typing indicators and it was never provisioned
// (typing silently no-ops). On web, typing (Phase 5) will use Firestore instead.
const firebaseConfig = {
  apiKey: firebaseEnv.apiKey,
  authDomain: firebaseEnv.authDomain,
  projectId: firebaseEnv.projectId,
  storageBucket: firebaseEnv.storageBucket,
  messagingSenderId: firebaseEnv.messagingSenderId,
  appId: firebaseEnv.appId,
};

if (!isFirebaseConfigured && import.meta.env.DEV) {
  // eslint-disable-next-line no-console
  console.warn(
    '[firebase] Missing config. Copy .env.example to .env.local and fill in the ' +
      'Web app values from the Firebase console (project: vetplus-digital).',
  );
}

export const app: FirebaseApp = getApps().length
  ? getApp()
  : initializeApp(firebaseConfig);

export const auth: Auth = getAuth(app);
export const db: Firestore = getFirestore(app);
export const storage: FirebaseStorage = getStorage(app);

const SECONDARY_NAME = 'secondary';

/** Get (or lazily create) the secondary app + its Auth, for provisioning users. */
export function getSecondaryAuth(): Auth {
  const existing = getApps().find((a) => a.name === SECONDARY_NAME);
  const secondaryApp = existing ?? initializeApp(firebaseConfig, SECONDARY_NAME);
  return getAuth(secondaryApp);
}
