// One-time migration from the solo-vet model (users.vetId) to clinics.
//
// Adds data only: no document is moved, deleted or re-keyed, and the legacy
// fields (vetId, bookedByVetId) stay so the old app keeps working until the
// clinic-aware app is deployed.
//
// Usage (gcloud Application Default Credentials, project owner's account):
//   GOOGLE_CLOUD_PROJECT=vetplus-digital STORAGE_BUCKET=<bucket> node scripts/migrate-to-clinics.mjs            # dry run
//   GOOGLE_CLOUD_PROJECT=vetplus-digital STORAGE_BUCKET=<bucket> node scripts/migrate-to-clinics.mjs --apply    # write
//   GOOGLE_CLOUD_PROJECT=vetplus-digital node scripts/migrate-to-clinics.mjs --verify                           # check
//
// Take a Firestore export before --apply. Every step is idempotent: re-running
// skips what is already migrated.

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { getDownloadURL, getStorage } from 'firebase-admin/storage';

const INES = 'sXs3DRjEQbZ0Gqtdt8z8KM66Zh13';
const SARAH = 'gs97zU7rRSdpp0nd0aebEW5frzS2';
const DRA_TESTE = 'SIzKTRpf7zVI11DPtKm7DAAGJLr1';

const CLINICS = [
  {
    id: 'yoshi-vet-care',
    name: 'Yoshi Vet Care',
    brand: { primary: '#FA5119', accent: '#EA9374' },
    logos: {
      wide: 'apps/web-react/src/assets/logo-wide.png',
      mark: 'apps/web-react/src/assets/logo-mark.png',
    },
    members: [{ uid: INES, role: 'owner' }],
    legacyVetIds: [INES],
    // Counted on 2026-11-22. --verify fails if the migrated data differs.
    expected: { clients: 24, rooms: 24, requests: 0, events: 1, privateNotes: 30, publicNotes: 2 },
  },
  {
    id: 'clinica-teste',
    name: 'Clínica Teste',
    brand: { primary: '#0E7C72', accent: '#4FD1C1' },
    logos: null,
    members: [
      { uid: SARAH, role: 'owner' },
      { uid: DRA_TESTE, role: 'vet' },
    ],
    legacyVetIds: [SARAH],
    expected: { clients: 3, rooms: 3, requests: 7, events: 8, privateNotes: 2, publicNotes: 1 },
  },
];

const NEW_IDS = new Set(CLINICS.map((c) => c.id));
const mode = process.argv.includes('--apply')
  ? 'apply'
  : process.argv.includes('--verify')
    ? 'verify'
    : 'dry-run';

if (process.env.GOOGLE_CLOUD_PROJECT !== 'vetplus-digital') {
  console.error('Set GOOGLE_CLOUD_PROJECT=vetplus-digital explicitly.');
  process.exit(1);
}
if (mode === 'apply' && !process.env.STORAGE_BUCKET) {
  console.error('Set STORAGE_BUCKET (VITE_FIREBASE_STORAGE_BUCKET in apps/web-react/.env.local).');
  process.exit(1);
}

initializeApp({
  credential: applicationDefault(),
  projectId: 'vetplus-digital',
  storageBucket: process.env.STORAGE_BUCKET,
});
const db = getFirestore();
const now = Date.now();

/* ------------------------------ write planning ----------------------------- */

const ops = []; // { ref, kind: 'set'|'merge'|'update', data, label }
const conflicts = [];
const counts = {};
const bump = (clinicId, key) => {
  counts[clinicId] ??= {};
  counts[clinicId][key] = (counts[clinicId][key] ?? 0) + 1;
};
const plan = (clinicId, key, ref, kind, data) => {
  bump(clinicId, key);
  ops.push({ ref, kind, data, label: `${clinicId}/${key}` });
};

/**
 * Old Flutter docs may carry a clinicId from the archived clinic model. Those
 * are overwritten (kept in legacyClinicId); a clinicId that is already one of
 * the new clinics but a different one is a conflict and the doc is skipped.
 */
function clinicIdPatch(docData, clinicId, path) {
  const current = docData.clinicId ?? null;
  if (current === clinicId) return null;
  if (current && NEW_IDS.has(current)) {
    conflicts.push(`${path}: clinicId ${current}, expected ${clinicId}`);
    return null;
  }
  if (!current) return { clinicId };
  bump(clinicId, 'legacyClinicIdKept');
  return { clinicId, legacyClinicId: current };
}

async function planClinic(c) {
  const clinicRef = db.doc(`clinics/${c.id}`);
  const clinicSnap = await clinicRef.get();
  const firstOwner = (await db.doc(`users/${c.members[0].uid}`).get()).data() ?? {};

  if (!clinicSnap.exists) {
    plan(c.id, 'clinicDoc', clinicRef, 'set', {
      name: c.name,
      isActive: true,
      brand: { ...c.brand, logoWideUrl: null, logoMarkUrl: null },
      contact: {
        phone: firstOwner.phone ?? null,
        address: firstOwner.address ?? null,
        postalCode: firstOwner.postalCode ?? null,
      },
      createdAt: now,
      updatedAt: now,
    });
  }

  for (const m of c.members) {
    const user = await db.doc(`users/${m.uid}`).get();
    if (!user.exists || user.get('userType') !== 1) {
      conflicts.push(`member ${m.uid}: missing or not staff (userType ${user.get('userType')})`);
      continue;
    }
    const memberRef = db.doc(`clinics/${c.id}/members/${m.uid}`);
    if (!(await memberRef.get()).exists) {
      plan(c.id, 'members', memberRef, 'set', {
        role: m.role,
        displayName: user.get('displayName') ?? '',
        email: user.get('email') ?? '',
        active: true,
        joinedAt: now,
      });
    }
    if (!(user.get('memberOf') ?? []).includes(c.id)) {
      plan(c.id, 'memberOf', user.ref, 'update', { memberOf: FieldValue.arrayUnion(c.id) });
    }
  }

  const clientIds = new Set();
  for (const vetId of c.legacyVetIds) {
    const vet = (await db.doc(`users/${vetId}`).get()).data() ?? {};

    const clients = await db.collection('users').where('vetId', '==', vetId).get();
    for (const doc of clients.docs) {
      if (doc.get('userType') !== 0) {
        conflicts.push(`users/${doc.id}: has vetId but userType ${doc.get('userType')}`);
        continue;
      }
      clientIds.add(doc.id);
      bump(c.id, 'sourceClients');
      const linkRef = db.doc(`clinics/${c.id}/clients/${doc.id}`);
      if (!(await linkRef.get()).exists) {
        plan(c.id, 'clientLinks', linkRef, 'set', {
          clientId: doc.id,
          status: 'active',
          addedBy: vetId,
          addedByName: vet.displayName ?? '',
          addedAt: doc.get('createdAt') ?? now,
          respondedAt: null,
          clinicName: c.name,
          clientName: doc.get('displayName') ?? '',
        });
      }
      if (!(doc.get('clientOf') ?? []).includes(c.id)) {
        plan(c.id, 'clientOf', doc.ref, 'update', { clientOf: FieldValue.arrayUnion(c.id) });
      }
    }

    // Rooms and requests: updatedAt is left alone so chat/request order doesn't change.
    const rooms = await db.collection('chatRooms').where('vetId', '==', vetId).get();
    for (const doc of rooms.docs) {
      bump(c.id, 'sourceRooms');
      if (!clientIds.has(doc.get('petOwnerId'))) {
        conflicts.push(`chatRooms/${doc.id}: petOwnerId ${doc.get('petOwnerId')} is not a client of ${c.id}`);
      }
      const patch = clinicIdPatch(doc.data(), c.id, `chatRooms/${doc.id}`);
      const data = { ...(patch ?? {}) };
      if (doc.get('requestedVetId') === undefined) data.requestedVetId = vetId;
      if (Object.keys(data).length) plan(c.id, 'rooms', doc.ref, 'update', data);
    }

    const requests = await db.collection('appointmentRequests').where('vetId', '==', vetId).get();
    for (const doc of requests.docs) {
      bump(c.id, 'sourceRequests');
      const patch = clinicIdPatch(doc.data(), c.id, `appointmentRequests/${doc.id}`);
      const data = { ...(patch ?? {}) };
      if (doc.get('requestedVetId') === undefined) data.requestedVetId = vetId;
      if (Object.keys(data).length) plan(c.id, 'requests', doc.ref, 'update', data);
    }

    // Only clinicId/vetId are added; the gcal trigger's hash guard ignores them.
    const events = await db.collectionGroup('events').where('bookedByVetId', '==', vetId).get();
    for (const doc of events.docs) {
      bump(c.id, 'sourceEvents');
      const owner = doc.ref.parent.parent?.id;
      if (!clientIds.has(owner)) {
        conflicts.push(`${doc.ref.path}: owner ${owner} is not a client of ${c.id}`);
      }
      const patch = clinicIdPatch(doc.data(), c.id, doc.ref.path);
      const data = { ...(patch ?? {}) };
      if (!doc.get('vetId')) data.vetId = vetId;
      if (Object.keys(data).length) plan(c.id, 'events', doc.ref, 'update', data);
    }
  }

  for (const clientId of clientIds) {
    const pets = await db.collection(`users/${clientId}/pets`).get();
    for (const pet of pets.docs) {
      for (const sub of ['private', 'publicNotes']) {
        const notes = await pet.ref.collection(sub).get();
        for (const note of notes.docs) {
          bump(c.id, sub === 'private' ? 'sourcePrivateNotes' : 'sourcePublicNotes');
          const patch = clinicIdPatch(note.data(), c.id, note.ref.path);
          if (patch) plan(c.id, sub === 'private' ? 'privateNotes' : 'publicNotes', note.ref, 'update', patch);
        }
      }
    }
  }
}

/* ---------------------------------- logos ---------------------------------- */

async function uploadLogos(c) {
  if (!c.logos) return;
  const clinicRef = db.doc(`clinics/${c.id}`);
  const brand = (await clinicRef.get()).get('brand') ?? {};
  const bucket = getStorage().bucket();
  const patch = {};
  for (const [key, field] of [['wide', 'logoWideUrl'], ['mark', 'logoMarkUrl']]) {
    if (brand[field]) continue;
    const file = bucket.file(`clinics/${c.id}/branding/logo-${key}.png`);
    await file.save(readFileSync(resolve(c.logos[key])), {
      contentType: 'image/png',
      metadata: { cacheControl: 'public, max-age=86400' },
    });
    patch[`brand.${field}`] = await getDownloadURL(file);
  }
  if (Object.keys(patch).length) await clinicRef.update(patch);
  console.log(`${c.id}: logos ${Object.keys(patch).length ? 'uploaded' : 'already set'}`);
}

/* --------------------------------- verify ---------------------------------- */

async function verify() {
  let ok = true;
  const [events, privateNotes, publicNotes] = await Promise.all([
    db.collectionGroup('events').get(),
    db.collectionGroup('private').get(),
    db.collectionGroup('publicNotes').get(),
  ]);
  for (const c of CLINICS) {
    const clinic = await db.doc(`clinics/${c.id}`).get();
    const members = await db.collection(`clinics/${c.id}/members`).get();
    const links = await db.collection(`clinics/${c.id}/clients`).where('status', '==', 'active').get();
    const clientOf = await db.collection('users').where('clientOf', 'array-contains', c.id).get();
    const memberOf = await db.collection('users').where('memberOf', 'array-contains', c.id).get();
    const rooms = await db.collection('chatRooms').where('clinicId', '==', c.id).get();
    const requests = await db.collection('appointmentRequests').where('clinicId', '==', c.id).get();
    const got = {
      clients: links.size,
      clientOf: clientOf.size,
      rooms: rooms.size,
      requests: requests.size,
      events: events.docs.filter((d) => d.get('clinicId') === c.id).length,
      privateNotes: privateNotes.docs.filter((d) => d.get('clinicId') === c.id).length,
      publicNotes: publicNotes.docs.filter((d) => d.get('clinicId') === c.id).length,
      members: members.size,
      memberOf: memberOf.size,
    };
    const want = {
      ...c.expected,
      clientOf: c.expected.clients,
      members: c.members.length,
      memberOf: c.members.length,
    };
    const bad = Object.keys(want).filter((k) => got[k] !== want[k]);
    if (!clinic.exists) bad.push('clinicDoc');
    ok &&= bad.length === 0;
    console.log(`${c.id}: ${JSON.stringify(got)}${bad.length ? `  MISMATCH: ${bad.join(', ')}` : '  OK'}`);
  }
  const unmigratedNotes = [...privateNotes.docs, ...publicNotes.docs].filter((d) => !d.get('clinicId'));
  if (unmigratedNotes.length) console.log(`notes without clinicId: ${unmigratedNotes.map((d) => d.ref.path).join(', ')}`);
  console.log(ok ? 'VERIFY OK' : 'VERIFY FAILED');
  process.exit(ok ? 0 : 1);
}

/* ---------------------------------- main ----------------------------------- */

if (mode === 'verify') await verify();

for (const c of CLINICS) await planClinic(c);

console.log(`mode: ${mode}`);
for (const c of CLINICS) {
  console.log(`${c.id}: ${JSON.stringify(counts[c.id] ?? {})}`);
  const src = counts[c.id] ?? {};
  const mismatch = [
    ['clients', src.sourceClients ?? 0],
    ['rooms', src.sourceRooms ?? 0],
    ['requests', src.sourceRequests ?? 0],
    ['events', src.sourceEvents ?? 0],
    ['privateNotes', src.sourcePrivateNotes ?? 0],
    ['publicNotes', src.sourcePublicNotes ?? 0],
  ].filter(([k, n]) => c.expected[k] !== n);
  if (mismatch.length) {
    conflicts.push(`${c.id}: source counts differ from expected: ${mismatch.map(([k, n]) => `${k}=${n} (expected ${c.expected[k]})`).join(', ')}`);
  }
}
console.log(`planned writes: ${ops.length}`);

if (conflicts.length) {
  console.log('CONFLICTS (nothing is written while there are conflicts):');
  for (const msg of conflicts) console.log(`  - ${msg}`);
  process.exit(1);
}

if (mode === 'dry-run') {
  console.log('Dry run only. Re-run with --apply to write.');
  process.exit(0);
}

for (let i = 0; i < ops.length; i += 400) {
  const batch = db.batch();
  for (const op of ops.slice(i, i + 400)) {
    if (op.kind === 'set') batch.set(op.ref, op.data);
    else batch.update(op.ref, op.data);
  }
  await batch.commit();
  console.log(`committed ${Math.min(i + 400, ops.length)}/${ops.length}`);
}
for (const c of CLINICS) await uploadLogos(c);
console.log('Done. Run with --verify to check.');
