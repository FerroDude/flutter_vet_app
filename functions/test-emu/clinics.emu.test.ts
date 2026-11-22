// Emulator integration tests for the clinic callables. Run via:
//   firebase emulators:exec --only firestore,auth --project demo-vetplus \
//     "npm --prefix functions run test:emu"
// Firebase Admin SDK talks to the emulators through the *_EMULATOR_HOST vars
// that emulators:exec exports.

import { beforeAll, beforeEach, describe, expect, it } from 'vitest';

process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';

const { initializeApp, deleteApp } = await import('firebase-admin/app');
const { getFirestore } = await import('firebase-admin/firestore');
const { getAuth } = await import('firebase-admin/auth');
const { HttpsError } = await import('firebase-functions/v2/https');
const clinics = await import('../src/clinics.js');
const { createClientLogin } = await import('../src/clients.js');

const A = 'clinic-a';
const B = 'clinic-b';

let app: ReturnType<typeof initializeApp>;
let db: ReturnType<typeof getFirestore>;
let auth: ReturnType<typeof getAuth>;

beforeAll(() => {
  app = initializeApp({ projectId: 'demo-vetplus' });
  db = getFirestore(app);
  auth = getAuth(app);
});

const member = (role: string, extra: object = {}) => ({
  role,
  displayName: 'M',
  email: 'm@m.pt',
  active: true,
  joinedAt: 1,
  ...extra,
});

const clientProfile = (clientOf: string[], extra: object = {}) => ({
  userType: 0,
  displayName: 'Cliente',
  email: 'c@c.pt',
  clientOf,
  ...extra,
});

async function seed() {
  const batch = db.batch();
  batch.set(db.doc(`clinics/${A}`), { name: 'Clinic A', isActive: true });
  batch.set(db.doc(`clinics/${B}`), { name: 'Clinic B', isActive: true });
  batch.set(db.doc('users/ownerA'), { userType: 1, displayName: 'Owner', memberOf: [A] });
  batch.set(db.doc('users/vetA'), { userType: 1, displayName: 'Vet', memberOf: [A] });
  batch.set(db.doc(`clinics/${A}/members/ownerA`), member('owner'));
  batch.set(db.doc(`clinics/${A}/members/vetA`), member('vet'));
  await batch.commit();
}

async function wipe() {
  const { docs } = await db.collection('users').get();
  const all = [
    ...(await db.collection('clinics').get()).docs,
    ...(await db.collection('users').get()).docs,
    ...(await db.collection('chatRooms').get()).docs,
    ...(await db.collection('appointmentRequests').get()).docs,
    ...docs,
  ];
  const batch = db.batch();
  for (const c of await db.collection('clinics').get().then((s) => s.docs)) {
    for (const m of await c.ref.collection('members').get().then((s) => s.docs)) batch.delete(m.ref);
    for (const l of await c.ref.collection('clients').get().then((s) => s.docs)) batch.delete(l.ref);
  }
  for (const d of all) batch.delete(d.ref);
  await batch.commit();
}

const code = (e: unknown) => (e as { code?: string }).code;

beforeEach(async () => {
  await wipe();
  await seed();
});

/* ------------------------------ addClinicClient --------------------------- */

describe('addClinicClient', () => {
  it('creates a profile-only client + active link without email', async () => {
    const r = await clinics.addClinicClient('ownerA', { clinicId: A, name: 'Ana' }, db, auth);
    expect(r).toMatchObject({ status: 'active', created: true });
    const profile = (await db.doc(`users/${r.clientId}`).get()).data();
    expect(profile?.userType).toBe(0);
    expect(profile?.clientOf).toEqual([A]);
    expect(profile?.invitePending).toBe(false);
    const link = (await db.doc(`clinics/${A}/clients/${r.clientId}`).get()).data();
    expect(link?.status).toBe('active');
  });

  it('creates auth user + profile + active link for a new email', async () => {
    const r = await clinics.addClinicClient(
      'ownerA',
      { clinicId: A, name: 'Ana', email: 'ana@nova.pt' },
      db,
      auth,
    );
    expect(r.created).toBe(true);
    const u = await auth.getUser(r.clientId);
    expect(u.email).toBe('ana@nova.pt');
    const profile = (await db.doc(`users/${r.clientId}`).get()).data();
    expect(profile?.invitePending).toBe(true);
  });

  it('creates a PENDING link for an existing unlinked client account', async () => {
    const u = await auth.createUser({ email: 'existe@x.pt' });
    await db.doc(`users/${u.uid}`).set(clientProfile([B], { displayName: 'Carla' }));
    const r = await clinics.addClinicClient(
      'ownerA',
      { clinicId: A, name: 'Carla', email: 'existe@x.pt' },
      db,
      auth,
    );
    expect(r).toMatchObject({ clientId: u.uid, status: 'pending', created: false });
    const link = (await db.doc(`clinics/${A}/clients/${u.uid}`).get()).data();
    expect(link?.status).toBe('pending');
    // clientOf stays untouched until the client accepts
    expect((await db.doc(`users/${u.uid}`).get()).data()?.clientOf).toEqual([B]);
  });

  it('refuses an already-linked client', async () => {
    const u = await auth.createUser({ email: 'ja@x.pt' });
    await db.doc(`users/${u.uid}`).set(clientProfile([A]));
    await db.doc(`clinics/${A}/clients/${u.uid}`).set({ status: 'active' });
    await expect(
      clinics.addClinicClient('ownerA', { clinicId: A, name: 'X', email: 'ja@x.pt' }, db, auth),
    ).rejects.toMatchObject({ code: 'already-exists' });
  });

  it('refuses a staff email and a non-member caller', async () => {
    const staffAuth = await auth.createUser({ email: 'equipa@x.pt' });
    await db.doc(`users/${staffAuth.uid}`).set({ userType: 1, memberOf: [] });
    await expect(
      clinics.addClinicClient('ownerA', { clinicId: A, name: 'X', email: 'equipa@x.pt' }, db, auth),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(
      clinics.addClinicClient('stranger', { clinicId: A, name: 'X' }, db, auth),
    ).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(
      clinics.addClinicClient('ownerA', { clinicId: A, name: 'X', email: 'bad' }, db, auth),
    ).rejects.toMatchObject({ code: 'invalid-argument' });
  });
});

/* ----------------------------- respondClinicLink -------------------------- */

describe('respondClinicLink', () => {
  it('accept activates the link and adds the clinic to clientOf', async () => {
    await db.doc('users/cli').set(clientProfile([]));
    await db.doc(`clinics/${A}/clients/cli`).set({ status: 'pending', clientId: 'cli' });
    const r = await clinics.respondClinicLink('cli', { clinicId: A, accept: true }, db);
    expect(r.status).toBe('active');
    expect((await db.doc(`clinics/${A}/clients/cli`).get()).data()?.status).toBe('active');
    expect((await db.doc('users/cli').get()).data()?.clientOf).toEqual([A]);
  });

  it('decline marks the link declined and adds nothing', async () => {
    await db.doc('users/cli').set(clientProfile([]));
    await db.doc(`clinics/${A}/clients/cli`).set({ status: 'pending', clientId: 'cli' });
    const r = await clinics.respondClinicLink('cli', { clinicId: A, accept: false }, db);
    expect(r.status).toBe('declined');
    expect((await db.doc('users/cli').get()).data()?.clientOf).toEqual([]);
  });

  it('fails without a pending link', async () => {
    await db.doc('users/cli').set(clientProfile([]));
    await expect(
      clinics.respondClinicLink('cli', { clinicId: A, accept: true }, db),
    ).rejects.toMatchObject({ code: 'not-found' });
  });
});

/* ------------------------------ createClinicVet --------------------------- */

describe('createClinicVet', () => {
  it('creates auth user + staff profile + member doc', async () => {
    const r = await clinics.createClinicVet(
      'ownerA',
      { clinicId: A, email: 'nova@vet.pt', name: 'Dra. Nova', role: 'vet' },
      db,
      auth,
    );
    expect(r.created).toBe(true);
    expect((await db.doc(`users/${r.uid}`).get()).data()?.memberOf).toEqual([A]);
    const m = (await db.doc(`clinics/${A}/members/${r.uid}`).get()).data();
    expect(m?.role).toBe('vet');
    expect(m?.active).toBe(true);
  });

  it('(re)adds an existing staff account without duplicating', async () => {
    const u = await auth.createUser({ email: 'voltou@vet.pt' });
    await db.doc(`users/${u.uid}`).set({ userType: 1, memberOf: [B] });
    const r = await clinics.createClinicVet(
      'ownerA',
      { clinicId: A, email: 'voltou@vet.pt', name: 'V', role: 'vet' },
      db,
      auth,
    );
    expect(r.created).toBe(false);
    expect((await db.doc(`users/${u.uid}`).get()).data()?.memberOf).toEqual([B, A]);
  });

  it('refuses a client email and a non-owner caller', async () => {
    const u = await auth.createUser({ email: 'cli@x.pt' });
    await db.doc(`users/${u.uid}`).set(clientProfile([A]));
    await expect(
      clinics.createClinicVet('ownerA', { clinicId: A, email: 'cli@x.pt', name: 'X', role: 'vet' }, db, auth),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(
      clinics.createClinicVet('vetA', { clinicId: A, email: 'n@x.pt', name: 'X', role: 'vet' }, db, auth),
    ).rejects.toMatchObject({ code: 'permission-denied' });
  });
});

/* ----------------------------- updateClinicMember ------------------------- */

describe('updateClinicMember', () => {
  it('refuses to remove the last active owner', async () => {
    await expect(
      clinics.updateClinicMember('ownerA', { clinicId: A, uid: 'ownerA', active: false }, db),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(
      clinics.updateClinicMember('ownerA', { clinicId: A, uid: 'ownerA', role: 'vet' }, db),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
    // with a second owner it's fine
    await db.doc(`clinics/${A}/members/owner2`).set(member('owner'));
    await db.doc('users/owner2').set({ userType: 1, memberOf: [A] });
    await expect(
      clinics.updateClinicMember('ownerA', { clinicId: A, uid: 'ownerA', role: 'vet' }, db),
    ).resolves.toEqual({ ok: true });
  });

  it('deactivation releases only that clinic’s rooms and pending requests', async () => {
    await db.doc('chatRooms/rA').set({ clinicId: A, vetId: 'vetA', vetName: 'V', status: 1 });
    await db.doc('chatRooms/rB').set({ clinicId: B, vetId: 'vetA', vetName: 'V', status: 1 });
    await db.doc('appointmentRequests/pA').set({ clinicId: A, vetId: 'vetA', status: 0 });
    await db.doc('appointmentRequests/done').set({ clinicId: A, vetId: 'vetA', status: 1 });
    await db.doc('appointmentRequests/pB').set({ clinicId: B, vetId: 'vetA', status: 0 });

    await clinics.updateClinicMember('ownerA', { clinicId: A, uid: 'vetA', active: false }, db);

    expect((await db.doc('chatRooms/rA').get()).data()).toMatchObject({
      vetId: null,
      vetName: null,
      status: 0,
    });
    expect((await db.doc('chatRooms/rB').get()).data()?.vetId).toBe('vetA');
    expect((await db.doc('appointmentRequests/pA').get()).data()?.vetId).toBeNull();
    expect((await db.doc('appointmentRequests/done').get()).data()?.vetId).toBe('vetA');
    expect((await db.doc('appointmentRequests/pB').get()).data()?.vetId).toBe('vetA');
    expect((await db.doc('users/vetA').get()).data()?.memberOf).toEqual([]);
    expect((await db.doc(`clinics/${A}/members/vetA`).get()).data()?.active).toBe(false);
  });

  it('reactivation restores membership', async () => {
    await clinics.updateClinicMember('ownerA', { clinicId: A, uid: 'vetA', active: false }, db);
    await clinics.updateClinicMember('ownerA', { clinicId: A, uid: 'vetA', active: true }, db);
    expect((await db.doc('users/vetA').get()).data()?.memberOf).toEqual([A]);
    expect((await db.doc(`clinics/${A}/members/vetA`).get()).data()?.active).toBe(true);
  });
});

/* ------------------------------ createClientLogin ------------------------- */

describe('createClientLogin clinic check', () => {
  it('allows staff of a linked clinic, denies everyone else', async () => {
    await db.doc('users/cli').set(clientProfile([A], { email: '', invitePending: true }));
    const r = await createClientLogin('vetA', { clientId: 'cli', email: 'cli@novo.pt' }, db);
    expect(r).toEqual({ ok: true });
    expect((await auth.getUser('cli')).email).toBe('cli@novo.pt');

    await db.doc('users/cli2').set(clientProfile([B]));
    await expect(
      createClientLogin('vetA', { clientId: 'cli2', email: 'x@x.pt' }, db),
    ).rejects.toMatchObject({ code: 'permission-denied' });
  });
});
