// Create a new clinic with its first owner. The owner must already be a staff
// account (create one with `npm run create-vet` first). Adds data only and
// refuses to touch a clinic id that already exists.
//
// Usage (gcloud Application Default Credentials, project owner's account):
//   GOOGLE_CLOUD_PROJECT=vetplus-digital npm run create-clinic -- <clinic-id> "<Name>" <owner-email> [#RRGGBB]
//   ... add --apply to write; without it the script only prints the plan.

import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const apply = process.argv.includes('--apply');
const [clinicId, name, emailArg, primaryArg] = process.argv
  .slice(2)
  .filter((a) => a !== '--apply');
const email = (emailArg ?? '').trim().toLowerCase();
const primary = primaryArg ?? '#0E7C72';

if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(clinicId ?? '') || !name?.trim() || !email.includes('@')) {
  console.error('Usage: npm run create-clinic -- <clinic-id> "<Name>" <owner-email> [#RRGGBB] [--apply]');
  process.exit(1);
}
if (!/^#[0-9a-f]{6}$/i.test(primary)) {
  console.error(`Invalid color ${primary}; use #RRGGBB.`);
  process.exit(1);
}
if (process.env.GOOGLE_CLOUD_PROJECT !== 'vetplus-digital') {
  console.error('Set GOOGLE_CLOUD_PROJECT=vetplus-digital explicitly.');
  process.exit(1);
}

initializeApp({ credential: applicationDefault(), projectId: 'vetplus-digital' });
const db = getFirestore();

const clinicRef = db.doc(`clinics/${clinicId}`);
if ((await clinicRef.get()).exists) {
  console.error(`clinics/${clinicId} already exists. Not touching it.`);
  process.exit(1);
}

// Looked up in Firestore (not Auth): Auth admin calls need an ADC quota project.
const matches = await db.collection('users').where('email', '==', email).get();
if (matches.size !== 1) {
  console.error(`Expected exactly one users/* doc with email ${email}, found ${matches.size}.`);
  process.exit(1);
}
const owner = { uid: matches.docs[0].id };
const ownerRef = matches.docs[0].ref;
const profile = matches.docs[0].data();
if (profile.userType !== 1) {
  console.error(`${email} is not a staff account (users/${owner.uid} userType != 1).`);
  process.exit(1);
}

const now = Date.now();
const clinicDoc = {
  name: name.trim(),
  isActive: true,
  brand: { primary: primary.toUpperCase(), accent: null, logoWideUrl: null, logoMarkUrl: null },
  contact: { phone: null, address: null, postalCode: null },
  createdAt: now,
  updatedAt: now,
};
const memberDoc = {
  role: 'owner',
  displayName: profile.displayName || name.trim(),
  email,
  active: true,
  joinedAt: now,
};

console.log(`clinics/${clinicId}`, clinicDoc);
console.log(`clinics/${clinicId}/members/${owner.uid}`, memberDoc);
console.log(`users/${owner.uid}.memberOf += ${clinicId}`);

if (!apply) {
  console.log('\nDry run. Re-run with --apply to write.');
  process.exit(0);
}

await db.runTransaction(async (tx) => {
  if ((await tx.get(clinicRef)).exists) throw new Error(`clinics/${clinicId} appeared meanwhile.`);
  tx.create(clinicRef, clinicDoc);
  tx.create(db.doc(`clinics/${clinicId}/members/${owner.uid}`), memberDoc);
  tx.update(ownerRef, { memberOf: FieldValue.arrayUnion(clinicId), updatedAt: now });
});
console.log(`\nCreated ${clinicId}. ${email} is its owner.`);
