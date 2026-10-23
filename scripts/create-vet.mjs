// Provision a vet account. In-app sign-up is disabled and Firestore rules
// refuse self-created profiles, so this Admin SDK script is the only way to
// add a vet.
//
// Usage:
//   GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json \
//     npm run create-vet -- vet@example.com "Dra. Nome"
//
// The service account key comes from Firebase console > Project settings >
// Service accounts. Never commit it.
//
// Prints a password-setup link to send to the vet. She can also use
// "Esqueci-me da palavra-passe" on the login screen.

import { randomBytes } from 'node:crypto';
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

const [emailArg, ...nameParts] = process.argv.slice(2);
const email = (emailArg ?? '').trim().toLowerCase();
const displayName = nameParts.join(' ').trim();

if (!email || !email.includes('@')) {
  console.error('Usage: npm run create-vet -- <email> [display name]');
  process.exit(1);
}

initializeApp({ credential: applicationDefault() });
const auth = getAuth();
const db = getFirestore();

let user;
try {
  user = await auth.getUserByEmail(email);
  console.log(`Auth user already exists: ${user.uid}`);
} catch (e) {
  if (e?.code !== 'auth/user-not-found') throw e;
  user = await auth.createUser({
    email,
    emailVerified: true,
    password: randomBytes(24).toString('base64'),
    displayName: displayName || undefined,
  });
  console.log(`Created Auth user: ${user.uid}`);
}

const ref = db.collection('users').doc(user.uid);
const existing = await ref.get();
if (existing.exists && existing.get('userType') !== 1) {
  console.error(
    `users/${user.uid} already exists with userType ${existing.get('userType')}. Not overwriting.`,
  );
  process.exit(1);
}

const now = Date.now();
await ref.set(
  {
    email,
    displayName: displayName || existing.get('displayName') || '',
    userType: 1,
    connectedClinicId: null,
    vetId: null,
    clinicRole: null,
    phone: existing.get('phone') ?? null,
    address: existing.get('address') ?? null,
    hasSkippedClinicSelection: true,
    mustChangePassword: false,
    createdAt: existing.get('createdAt') ?? now,
    updatedAt: now,
    isActive: true,
    globalType: null,
    fcmToken: existing.get('fcmToken') ?? null,
  },
  { merge: true },
);

const link = await auth.generatePasswordResetLink(email);
console.log(`Vet profile ready: users/${user.uid}`);
console.log(`Password setup link:\n${link}`);
