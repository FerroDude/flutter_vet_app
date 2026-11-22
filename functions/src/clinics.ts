// Clinic membership: staff roster and client links.
//
// users/{uid} carries memberOf/clientOf arrays; the truth for ROLES lives in
// clinics/{c}/members/{uid} (owner | vet) and for client links in
// clinics/{c}/clients/{uid} (pending | active | declined). All of those docs
// are server-written only — these callables are the single write path.
//
// Every function takes (callerUid, data, db, auth) so it stays unit-testable;
// index.ts only wires onCall + the auth check.

import { randomBytes } from 'node:crypto';
import type { Auth } from 'firebase-admin/auth';
import {
  FieldValue,
  type DocumentData,
  type DocumentReference,
  type Firestore,
  type UpdateData,
} from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { normalizeEmail } from './clients.js';

const authCode = (e: unknown): string | undefined => (e as { code?: string })?.code;

type Data = Record<string, unknown>;

function arg(data: unknown): Data {
  if (typeof data !== 'object' || data === null) {
    throw new HttpsError('invalid-argument', 'Pedido inválido.');
  }
  return data as Data;
}

function requireString(v: unknown, msg: string): string {
  if (typeof v !== 'string' || !v.trim()) throw new HttpsError('invalid-argument', msg);
  return v.trim();
}

interface MemberDoc {
  role?: string;
  active?: boolean;
  displayName?: string;
  email?: string;
}

/** Throws unless uid is an ACTIVE member of clinicId. Returns the member doc. */
export async function requireMember(
  db: Firestore,
  uid: string,
  clinicId: string,
): Promise<MemberDoc> {
  const snap = await db.doc(`clinics/${clinicId}/members/${uid}`).get();
  const m = snap.data() as MemberDoc | undefined;
  if (!snap.exists || m?.active !== true) {
    throw new HttpsError('permission-denied', 'Não é membro desta clínica.');
  }
  return m ?? {};
}

/** Throws unless uid is an ACTIVE owner of clinicId. */
export async function requireOwner(
  db: Firestore,
  uid: string,
  clinicId: string,
): Promise<MemberDoc> {
  const m = await requireMember(db, uid, clinicId);
  if (m.role !== 'owner') {
    throw new HttpsError('permission-denied', 'Só o proprietário pode fazer isto.');
  }
  return m;
}

async function clinicName(db: Firestore, clinicId: string): Promise<string> {
  const snap = await db.doc(`clinics/${clinicId}`).get();
  if (!snap.exists || snap.data()?.isActive === false) {
    throw new HttpsError('not-found', 'Clínica não encontrada.');
  }
  return (snap.data()?.name as string) ?? '';
}

function clientProfileDoc(name: string, email: string, clinicId: string): Data {
  const now = Date.now();
  return {
    email,
    displayName: name,
    userType: 0,
    connectedClinicId: null,
    vetId: null,
    clinicRole: null,
    phone: null,
    phone2: null,
    address: null,
    postalCode: null,
    country: null,
    nif: null,
    hasSkippedClinicSelection: true,
    mustChangePassword: false,
    createdAt: now,
    updatedAt: now,
    isActive: true,
    globalType: null,
    fcmToken: null,
    invitePending: Boolean(email),
    invitedAt: null,
    memberOf: [],
    clientOf: [clinicId],
  };
}

function linkDoc(
  clientId: string,
  clientName: string,
  clinic: string,
  status: 'pending' | 'active',
  addedBy: string,
  addedByName: string,
): Data {
  return {
    clientId,
    clientName,
    clinicName: clinic,
    status,
    addedBy,
    addedByName,
    addedAt: Date.now(),
    respondedAt: null,
  };
}

/**
 * addClinicClient({ clinicId, name, email? }) — a clinic member adds a client.
 * No email or unknown email → new profile + ACTIVE link. Known email with a
 * client profile not yet linked → PENDING link the client must accept.
 */
export async function addClinicClient(
  caller: string,
  data: unknown,
  db: Firestore,
  auth: Auth,
): Promise<{ clientId: string; status: 'pending' | 'active'; created: boolean }> {
  const d = arg(data);
  const clinicId = requireString(d.clinicId, 'Falta a clínica.');
  const name = requireString(d.name, 'Falta o nome do cliente.');
  const email = d.email == null || d.email === '' ? null : normalizeEmail(d.email);
  if (d.email != null && d.email !== '' && !email) {
    throw new HttpsError('invalid-argument', 'Email inválido.');
  }

  const callerMember = await requireMember(db, caller, clinicId);
  const clinic = await clinicName(db, clinicId);
  const addedByName =
    callerMember.displayName ??
    ((await db.doc(`users/${caller}`).get()).data()?.displayName as string) ??
    '';

  const writeLink = (clientId: string, clientName: string, status: 'pending' | 'active') =>
    db
      .doc(`clinics/${clinicId}/clients/${clientId}`)
      .set(linkDoc(clientId, clientName, clinic, status, caller, addedByName));

  // No email → profile-only client, active immediately.
  if (!email) {
    const ref = db.collection('users').doc();
    const batch = db.batch();
    batch.set(ref, clientProfileDoc(name, '', clinicId));
    batch.set(
      db.doc(`clinics/${clinicId}/clients/${ref.id}`),
      linkDoc(ref.id, name, clinic, 'active', caller, addedByName),
    );
    await batch.commit();
    return { clientId: ref.id, status: 'active', created: true };
  }

  let authUser: { uid: string } | null = null;
  try {
    authUser = await auth.getUserByEmail(email);
  } catch (e) {
    if (authCode(e) !== 'auth/user-not-found') throw e;
  }

  if (!authUser) {
    const created = await auth.createUser({
      email,
      password: randomBytes(24).toString('base64'),
      emailVerified: false,
    });
    const batch = db.batch();
    batch.set(db.doc(`users/${created.uid}`), clientProfileDoc(name, email, clinicId));
    batch.set(
      db.doc(`clinics/${clinicId}/clients/${created.uid}`),
      linkDoc(created.uid, name, clinic, 'active', caller, addedByName),
    );
    await batch.commit();
    return { clientId: created.uid, status: 'active', created: true };
  }

  const profileRef = db.doc(`users/${authUser.uid}`);
  const profile = (await profileRef.get()).data();
  if (!profile || profile.userType !== 0) {
    throw new HttpsError(
      'failed-precondition',
      'Esse email pertence a uma conta de equipa ou não tem perfil.',
    );
  }
  const linkRef = db.doc(`clinics/${clinicId}/clients/${authUser.uid}`);
  const link = (await linkRef.get()).data();
  const clientOf = (profile.clientOf as string[] | undefined) ?? [];
  if (clientOf.includes(clinicId) || link?.status === 'active') {
    throw new HttpsError('already-exists', 'Este cliente já está ligado à clínica.');
  }

  await writeLink(authUser.uid, (profile.displayName as string) || name, 'pending');
  return { clientId: authUser.uid, status: 'pending', created: false };
}

/**
 * respondClinicLink({ clinicId, accept }) — the CLIENT answers a pending link.
 * Accept → link active + clientOf[] += clinicId (one transaction).
 * Decline → link declined. Nothing is shared while pending.
 */
export async function respondClinicLink(
  caller: string,
  data: unknown,
  db: Firestore,
): Promise<{ status: 'active' | 'declined' }> {
  const d = arg(data);
  const clinicId = requireString(d.clinicId, 'Falta a clínica.');
  if (typeof d.accept !== 'boolean') {
    throw new HttpsError('invalid-argument', 'Falta a resposta.');
  }

  const linkRef = db.doc(`clinics/${clinicId}/clients/${caller}`);
  const link = (await linkRef.get()).data();
  if (!link || link.status !== 'pending') {
    throw new HttpsError('not-found', 'Não há convite pendente desta clínica.');
  }

  const now = Date.now();
  if (!d.accept) {
    await linkRef.update({ status: 'declined', respondedAt: now });
    return { status: 'declined' };
  }

  const userRef = db.doc(`users/${caller}`);
  await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) throw new HttpsError('not-found', 'Perfil não encontrado.');
    tx.update(linkRef, { status: 'active', respondedAt: now });
    tx.update(userRef, { clientOf: FieldValue.arrayUnion(clinicId), updatedAt: now });
  });
  return { status: 'active' };
}

function memberDoc(role: string, name: string, email: string): Data {
  return { role, displayName: name, email, active: true, joinedAt: Date.now() };
}

function staffProfileDoc(name: string, email: string, clinicId: string): Data {
  const now = Date.now();
  return {
    email,
    displayName: name,
    userType: 1,
    connectedClinicId: null,
    vetId: null,
    clinicRole: null,
    phone: null,
    address: null,
    hasSkippedClinicSelection: true,
    mustChangePassword: false,
    createdAt: now,
    updatedAt: now,
    isActive: true,
    globalType: null,
    fcmToken: null,
    memberOf: [clinicId],
    clientOf: [],
  };
}

/**
 * createClinicVet({ clinicId, email, name, role }) — an owner adds a vet/owner.
 * Existing staff account → (re)activate membership; existing client → error
 * (no dual roles); unknown → Auth user + profile + member doc.
 */
export async function createClinicVet(
  caller: string,
  data: unknown,
  db: Firestore,
  auth: Auth,
): Promise<{ uid: string; created: boolean }> {
  const d = arg(data);
  const clinicId = requireString(d.clinicId, 'Falta a clínica.');
  const name = requireString(d.name, 'Falta o nome.');
  const email = normalizeEmail(d.email);
  if (!email) throw new HttpsError('invalid-argument', 'Email inválido.');
  const role = requireString(d.role, 'Falta o papel.');
  if (role !== 'owner' && role !== 'vet') {
    throw new HttpsError('invalid-argument', 'Papel inválido.');
  }

  await requireOwner(db, caller, clinicId);
  await clinicName(db, clinicId);

  let authUser: { uid: string } | null = null;
  try {
    authUser = await auth.getUserByEmail(email);
  } catch (e) {
    if (authCode(e) !== 'auth/user-not-found') throw e;
  }

  if (authUser) {
    const profileRef = db.doc(`users/${authUser.uid}`);
    const profile = (await profileRef.get()).data();
    if (!profile || profile.userType !== 1) {
      throw new HttpsError(
        'failed-precondition',
        'Esse email pertence a uma conta de cliente — não pode ser equipa.',
      );
    }
    const memberRef = db.doc(`clinics/${clinicId}/members/${authUser.uid}`);
    const prev = (await memberRef.get()).data();
    const batch = db.batch();
    batch.set(memberRef, { ...memberDoc(role, name, email), joinedAt: prev?.joinedAt ?? Date.now() });
    batch.update(profileRef, {
      memberOf: FieldValue.arrayUnion(clinicId),
      updatedAt: Date.now(),
    });
    await batch.commit();
    return { uid: authUser.uid, created: false };
  }

  const created = await auth.createUser({
    email,
    password: randomBytes(24).toString('base64'),
    emailVerified: false,
    displayName: name,
  });
  const batch = db.batch();
  batch.set(db.doc(`users/${created.uid}`), staffProfileDoc(name, email, clinicId));
  batch.set(db.doc(`clinics/${clinicId}/members/${created.uid}`), memberDoc(role, name, email));
  await batch.commit();
  return { uid: created.uid, created: true };
}

const MAX_BATCH_WRITES = 400;

/**
 * updateClinicMember({ clinicId, uid, role?, active? }) — owner edits the
 * roster. Deactivation releases the vet's rooms/requests of THAT clinic back
 * to the pool. Never leaves the clinic without an active owner.
 */
export async function updateClinicMember(
  caller: string,
  data: unknown,
  db: Firestore,
): Promise<{ ok: true }> {
  const d = arg(data);
  const clinicId = requireString(d.clinicId, 'Falta a clínica.');
  const uid = requireString(d.uid, 'Falta o membro.');
  const role = d.role === undefined ? undefined : requireString(d.role, 'Papel inválido.');
  const active = d.active === undefined ? undefined : d.active;
  if (role === undefined && active === undefined) {
    throw new HttpsError('invalid-argument', 'Nada para alterar.');
  }
  if (role !== undefined && role !== 'owner' && role !== 'vet') {
    throw new HttpsError('invalid-argument', 'Papel inválido.');
  }
  if (active !== undefined && typeof active !== 'boolean') {
    throw new HttpsError('invalid-argument', 'Campo active inválido.');
  }

  await requireOwner(db, caller, clinicId);
  const memberRef = db.doc(`clinics/${clinicId}/members/${uid}`);
  const memberSnap = await memberRef.get();
  const member = memberSnap.data() as MemberDoc | undefined;
  if (!memberSnap.exists || !member) {
    throw new HttpsError('not-found', 'Membro não encontrado.');
  }

  const nextRole = role ?? member.role;
  const nextActive = active ?? member.active !== false;
  const losingOwner = member.role === 'owner' && member.active === true &&
    (nextRole !== 'owner' || nextActive === false);
  if (losingOwner) {
    const owners = await db
      .collection(`clinics/${clinicId}/members`)
      .where('role', '==', 'owner')
      .where('active', '==', true)
      .get();
    if (owners.size <= 1) {
      throw new HttpsError(
        'failed-precondition',
        'A clínica tem de ficar com pelo menos um proprietário ativo.',
      );
    }
  }

  const batch = db.batch();
  const update: UpdateData<DocumentData> = {};
  if (role !== undefined) update.role = nextRole;
  if (active !== undefined) update.active = nextActive;
  batch.update(memberRef, update);

  const userRef = db.doc(`users/${uid}`);
  const deactivating = nextActive === false && member.active === true;
  const reactivating = nextActive === true && member.active === false;
  if (deactivating) {
    batch.update(userRef, {
      memberOf: FieldValue.arrayRemove(clinicId),
      updatedAt: Date.now(),
    });
  } else if (reactivating) {
    batch.update(userRef, {
      memberOf: FieldValue.arrayUnion(clinicId),
      updatedAt: Date.now(),
    });
  }
  await batch.commit();

  if (deactivating) {
    // Release this vet's rooms and still-pending requests of THIS clinic back
    // to the pool (other clinics' assignments are untouched). Chunked commits
    // so nothing is silently dropped past the batch limit.
    const [rooms, requests] = await Promise.all([
      db.collection('chatRooms').where('clinicId', '==', clinicId).where('vetId', '==', uid).get(),
      db
        .collection('appointmentRequests')
        .where('clinicId', '==', clinicId)
        .where('vetId', '==', uid)
        .where('status', '==', 0)
        .get(),
    ]);
    const now = Date.now();
    const releases: { ref: DocumentReference; data: UpdateData<DocumentData> }[] = [
      ...rooms.docs.map((d) => ({
        ref: d.ref,
        data: { vetId: null, vetName: null, status: 0, releasedAt: now, updatedAt: now },
      })),
      ...requests.docs.map((d) => ({
        ref: d.ref,
        data: { vetId: null, updatedAt: now },
      })),
    ];
    for (let i = 0; i < releases.length; i += MAX_BATCH_WRITES) {
      const chunk = db.batch();
      for (const r of releases.slice(i, i + MAX_BATCH_WRITES)) {
        chunk.update(r.ref, r.data);
      }
      await chunk.commit();
    }
  }
  return { ok: true };
}
