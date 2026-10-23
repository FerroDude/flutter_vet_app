// Centralized, typed access to Vite env vars. Fails loudly in dev if the
// Firebase config is missing so the cause is obvious.

interface FirebaseEnv {
  apiKey: string;
  authDomain: string;
  projectId: string;
  storageBucket: string;
  messagingSenderId: string;
  appId: string;
}

function read(key: string): string {
  return (import.meta.env[key] as string | undefined)?.trim() ?? '';
}

export const firebaseEnv: FirebaseEnv = {
  apiKey: read('VITE_FIREBASE_API_KEY'),
  authDomain: read('VITE_FIREBASE_AUTH_DOMAIN'),
  projectId: read('VITE_FIREBASE_PROJECT_ID'),
  storageBucket: read('VITE_FIREBASE_STORAGE_BUCKET'),
  messagingSenderId: read('VITE_FIREBASE_MESSAGING_SENDER_ID'),
  appId: read('VITE_FIREBASE_APP_ID'),
};

export const isFirebaseConfigured = Boolean(
  firebaseEnv.apiKey && firebaseEnv.projectId && firebaseEnv.appId,
);
