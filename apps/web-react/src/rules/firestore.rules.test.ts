import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  addDoc,
  collection,
  collectionGroup,
  query,
  where,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  serverTimestamp,
} from 'firebase/firestore';

const rules = readFileSync(resolve(process.cwd(), '../../firestore.rules'), 'utf8');

let env: RulesTestEnvironment;

/* --------------------------------- fixture ---------------------------------
 * Clinics A and B. Staff: ownerA (owner A), vetA (vet A), ownerB (owner B),
 * vetAB (vet in A and B). Clients: clientA/clientA2 (linked to A), clientAB
 * (A and B), pendingB (active in A, pending link in B). stranger has no
 * profile. legacyUser is in a legacy clinics/X/members doc but has no memberOf.
 */
const A = 'clinic-a';
const B = 'clinic-b';
const LEGACY = 'G8f7mQbrLruWTc4Edi1i';

const users: Record<string, object> = {
  ownerA: { userType: 1, displayName: 'Dra. Owner', email: 'owner@a.pt', memberOf: [A] },
  vetA: { userType: 1, displayName: 'Dr. Vet', email: 'vet@a.pt', memberOf: [A] },
  ownerB: { userType: 1, displayName: 'Owner B', email: 'owner@b.pt', memberOf: [B] },
  vetAB: { userType: 1, displayName: 'Vet AB', email: 'vet@ab.pt', memberOf: [A, B] },
  clientA: { userType: 0, displayName: 'Ana', email: 'ana@a.pt', clientOf: [A] },
  clientA2: { userType: 0, displayName: 'Bruno', email: 'bruno@a.pt', clientOf: [A] },
  clientAB: { userType: 0, displayName: 'Carla', email: 'carla@ab.pt', clientOf: [A, B] },
  pendingB: { userType: 0, displayName: 'Pedro', email: 'pedro@a.pt', clientOf: [A] },
  legacyUser: { userType: 1, displayName: 'Legacy', email: 'l@l.pt', memberOf: [] },
};

const member = (role: string) => ({
  role,
  displayName: 'M',
  email: 'm@m.pt',
  active: true,
  joinedAt: 1,
});

const link = (clientId: string, clinicName: string, status: string) => ({
  clientId,
  clientName: clientId,
  clinicName,
  status,
  addedBy: 'ownerA',
  addedByName: 'Dra. Owner',
  addedAt: 1,
});

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-vetplus',
    firestore: { rules, host: '127.0.0.1', port: 8080 },
  });
});

afterAll(async () => {
  await env.cleanup();
});

type SeedDb = ReturnType<ReturnType<RulesTestEnvironment['unauthenticatedContext']>['firestore']>;

const seed = (writes: (db: SeedDb) => Promise<unknown>) =>
  env.withSecurityRulesDisabled(async (ctx) => {
    await writes(ctx.firestore());
  });

beforeEach(async () => {
  await env.clearFirestore();
  await seed(async (db) => {
    for (const [uid, data] of Object.entries(users)) {
      await setDoc(doc(db, 'users', uid), data);
    }
    await setDoc(doc(db, 'clinics', A), { name: 'Clinic A', isActive: true, brand: { primary: '#0E7C72' }, contact: {} });
    await setDoc(doc(db, 'clinics', B), { name: 'Clinic B', isActive: true, brand: { primary: '#000000' }, contact: {} });
    await setDoc(doc(db, `clinics/${A}/members/ownerA`), member('owner'));
    await setDoc(doc(db, `clinics/${A}/members/vetA`), member('vet'));
    await setDoc(doc(db, `clinics/${A}/members/vetAB`), member('vet'));
    await setDoc(doc(db, `clinics/${B}/members/ownerB`), member('owner'));
    await setDoc(doc(db, `clinics/${B}/members/vetAB`), member('vet'));
    await setDoc(doc(db, `clinics/${A}/clients/clientA`), link('clientA', 'Clinic A', 'active'));
    await setDoc(doc(db, `clinics/${A}/clients/clientA2`), link('clientA2', 'Clinic A', 'active'));
    await setDoc(doc(db, `clinics/${A}/clients/clientAB`), link('clientAB', 'Clinic A', 'active'));
    await setDoc(doc(db, `clinics/${A}/clients/pendingB`), link('pendingB', 'Clinic A', 'active'));
    await setDoc(doc(db, `clinics/${B}/clients/clientAB`), link('clientAB', 'Clinic B', 'active'));
    await setDoc(doc(db, `clinics/${B}/clients/pendingB`), link('pendingB', 'Clinic B', 'pending'));
    // Legacy Flutter clinic (auto-id) with a members subcollection nobody's
    // memberOf/clientOf references.
    await setDoc(doc(db, 'clinics', LEGACY), { name: 'Old Flutter Clinic' });
    await setDoc(doc(db, `clinics/${LEGACY}/members/legacyUser`), member('vet'));
  });
});

const db = (uid: string) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

/* ------------------------------- isolation -------------------------------- */

describe('clinic isolation', () => {
  it('scopes profiles and pets to shared clinics', async () => {
    await seed(async (d) => {
      await setDoc(doc(d, 'users/clientA/pets/luna'), { name: 'Luna' });
      await setDoc(doc(d, 'users/clientAB/pets/rex'), { name: 'Rex' });
      await setDoc(doc(d, 'users/pendingB/pets/miau'), { name: 'Miau' });
    });
    const ownerB = db('ownerB');
    // B staff sees nothing of an A-only client…
    await assertFails(getDoc(doc(ownerB, 'users/clientA')));
    await assertFails(getDoc(doc(ownerB, 'users/clientA/pets/luna')));
    // …but sees the shared client's data…
    await assertSucceeds(getDoc(doc(ownerB, 'users/clientAB')));
    await assertSucceeds(getDoc(doc(ownerB, 'users/clientAB/pets/rex')));
    // …and nothing of a pending-link client.
    await assertFails(getDoc(doc(ownerB, 'users/pendingB')));
    await assertFails(getDoc(doc(ownerB, 'users/pendingB/pets/miau')));
    // A staff sees all three A-linked clients.
    const vetA = db('vetA');
    await assertSucceeds(getDoc(doc(vetA, 'users/clientA')));
    await assertSucceeds(getDoc(doc(vetA, 'users/pendingB/pets/miau')));
  });

  it('keeps clients of the same clinic from reading each other', async () => {
    const clientA = db('clientA');
    await assertFails(getDoc(doc(clientA, 'users/clientA2')));
    await assertFails(getDoc(doc(clientA, 'users/clientA2/pets/x')));
  });

  it('lets a client read their clinics’ vets but not another clinic’s', async () => {
    const clientA = db('clientA');
    await assertSucceeds(getDoc(doc(clientA, 'users/vetA')));
    await assertSucceeds(getDoc(doc(clientA, 'users/ownerA')));
    await assertFails(getDoc(doc(clientA, 'users/ownerB')));
    // clientAB also reaches clinic-B staff, incl. the shared vet.
    const clientAB = db('clientAB');
    await assertSucceeds(getDoc(doc(clientAB, 'users/ownerB')));
    await assertSucceeds(getDoc(doc(clientAB, 'users/vetAB')));
  });

  it('lets colleagues of a shared clinic read each other', async () => {
    const vetA = db('vetA');
    await assertSucceeds(getDoc(doc(vetA, 'users/ownerA')));
    await assertSucceeds(getDoc(doc(vetA, 'users/vetAB')));
    await assertFails(getDoc(doc(vetA, 'users/ownerB')));
  });
});

/* -------------------------------- profiles -------------------------------- */

describe('user profile rules', () => {
  it('blocks all client-side profile creation and array self-edits', async () => {
    const stranger = db('stranger');
    await assertFails(setDoc(doc(stranger, 'users/stranger'), { userType: 0 }));
    const clientA = db('clientA');
    await assertFails(updateDoc(doc(clientA, 'users/clientA'), { clientOf: [A, B] }));
    await assertFails(updateDoc(doc(clientA, 'users/clientA'), { memberOf: [A] }));
    await assertFails(updateDoc(doc(clientA, 'users/clientA'), { vetId: 'vetA' }));
  });

  it('lets the client update their own contact fields', async () => {
    const clientA = db('clientA');
    await assertSucceeds(
      updateDoc(doc(clientA, 'users/clientA'), { phone2: '922', nif: '1', updatedAt: 2 }),
    );
  });

  it('lets clinic staff edit contact fields and the invite flag only on linked clients', async () => {
    const vetA = db('vetA');
    const ownerB = db('ownerB');
    const fields = { phone: '911', postalCode: '1000-001', updatedAt: 2 };
    await assertSucceeds(updateDoc(doc(vetA, 'users/clientA'), fields));
    await assertFails(updateDoc(doc(vetA, 'users/clientA'), { ...fields, displayName: 'X' }));
    await assertFails(updateDoc(doc(ownerB, 'users/clientA'), fields));
    await assertSucceeds(
      updateDoc(doc(vetA, 'users/clientA'), { invitePending: false, invitedAt: 2, updatedAt: 2 }),
    );
    await assertFails(
      updateDoc(doc(vetA, 'users/clientA'), { invitePending: true, invitedAt: null, updatedAt: 2 }),
    );
  });
});

/* --------------------------------- notes ---------------------------------- */

describe('private + public notes', () => {
  const seedNotes = () =>
    seed(async (d) => {
      await setDoc(doc(d, 'users/clientAB/pets/rex/private/nA'), { text: 'A', clinicId: A });
      await setDoc(doc(d, 'users/clientAB/pets/rex/private/nB'), { text: 'B', clinicId: B });
      await setDoc(doc(d, 'users/clientAB/pets/rex/publicNotes/pA'), { text: 'PA', clinicId: A });
      await setDoc(doc(d, 'users/clientAB/pets/rex/publicNotes/pB'), { text: 'PB', clinicId: B });
    });

  it('scopes private notes to the clinic', async () => {
    await seedNotes();
    const vetA = db('vetA');
    const ownerB = db('ownerB');
    const clientAB = db('clientAB');
    await assertSucceeds(getDoc(doc(vetA, 'users/clientAB/pets/rex/private/nA')));
    await assertFails(getDoc(doc(vetA, 'users/clientAB/pets/rex/private/nB')));
    await assertSucceeds(getDoc(doc(ownerB, 'users/clientAB/pets/rex/private/nB')));
    await assertFails(getDoc(doc(ownerB, 'users/clientAB/pets/rex/private/nA')));
    await assertFails(getDoc(doc(clientAB, 'users/clientAB/pets/rex/private/nA')));
    // list filtered by clinic works; unfiltered fails.
    await assertSucceeds(
      getDocs(query(collection(vetA, 'users/clientAB/pets/rex/private'), where('clinicId', '==', A))),
    );
    await assertFails(getDocs(collection(vetA, 'users/clientAB/pets/rex/private')));
  });

  it('lets the client read all public notes, staff only their clinic’s', async () => {
    await seedNotes();
    const clientAB = db('clientAB');
    const vetA = db('vetA');
    await assertSucceeds(getDoc(doc(clientAB, 'users/clientAB/pets/rex/publicNotes/pA')));
    await assertSucceeds(getDoc(doc(clientAB, 'users/clientAB/pets/rex/publicNotes/pB')));
    await assertSucceeds(getDoc(doc(vetA, 'users/clientAB/pets/rex/publicNotes/pA')));
    await assertFails(getDoc(doc(vetA, 'users/clientAB/pets/rex/publicNotes/pB')));
    await assertSucceeds(
      getDocs(query(collection(vetA, 'users/clientAB/pets/rex/publicNotes'), where('clinicId', '==', A))),
    );
  });

  it('validates the clinic on writes', async () => {
    await seed(async (d) => {
      await setDoc(doc(d, 'users/clientA/pets/luna'), { name: 'Luna' });
      await setDoc(doc(d, 'users/clientAB/pets/rex'), { name: 'Rex' });
    });
    const vetA = db('vetA');
    const ownerB = db('ownerB');
    const notes = collection(vetA, 'users/clientAB/pets/rex/publicNotes');
    await assertSucceeds(addDoc(notes, { text: 'ok', clinicId: A }));
    await assertFails(addDoc(notes, { text: 'x', clinicId: B })); // not my clinic
    await assertFails(addDoc(notes, { text: 'x' })); // no clinicId
    await assertFails(
      addDoc(collection(ownerB, 'users/clientA/pets/luna/publicNotes'), { text: 'x', clinicId: B }),
    ); // clientA not linked to B
    await assertFails(
      addDoc(collection(vetA, 'users/clientA/pets/luna/publicNotes'), { text: 'x', clinicId: B }),
    ); // vetA not in B
  });

  it('forbids changing clinicId on update', async () => {
    await seedNotes();
    const vetA = db('vetA');
    await assertSucceeds(
      updateDoc(doc(vetA, 'users/clientAB/pets/rex/private/nA'), { text: 'novo' }),
    );
    await assertFails(
      updateDoc(doc(vetA, 'users/clientAB/pets/rex/private/nA'), { text: 'x', clinicId: B }),
    );
  });
});

/* --------------------------------- events --------------------------------- */

describe('events', () => {
  const seedEvents = () =>
    seed(async (d) => {
      await setDoc(doc(d, 'users/clientAB/events/personal'), { title: 'P', userId: 'clientAB' });
      await setDoc(doc(d, 'users/clientAB/events/evtA'), {
        title: 'A', userId: 'clientAB', clinicId: A, vetId: 'vetA', bookedByVetId: 'vetA',
      });
      await setDoc(doc(d, 'users/clientAB/events/evtB'), {
        title: 'B', userId: 'clientAB', clinicId: B, vetId: 'ownerB', bookedByVetId: 'ownerB',
      });
    });

  it('personal events reach every linked clinic; clinic events only their own', async () => {
    await seedEvents();
    const vetA = db('vetA');
    const ownerB = db('ownerB');
    await assertSucceeds(getDoc(doc(vetA, 'users/clientAB/events/personal')));
    await assertSucceeds(getDoc(doc(ownerB, 'users/clientAB/events/personal')));
    await assertSucceeds(getDoc(doc(vetA, 'users/clientAB/events/evtA')));
    await assertFails(getDoc(doc(ownerB, 'users/clientAB/events/evtA')));
    await assertSucceeds(getDoc(doc(ownerB, 'users/clientAB/events/evtB')));
  });

  it('gates the agenda collection-group query on clinicId', async () => {
    await seedEvents();
    const vetA = db('vetA');
    const ownerB = db('ownerB');
    await assertSucceeds(
      getDocs(query(collectionGroup(vetA, 'events'), where('clinicId', '==', A))),
    );
    await assertSucceeds(
      getDocs(
        query(
          collectionGroup(vetA, 'events'),
          where('clinicId', '==', A),
          where('vetId', '==', 'vetA'),
        ),
      ),
    );
    await assertFails(
      getDocs(query(collectionGroup(ownerB, 'events'), where('clinicId', '==', A))),
    );
    await assertFails(getDocs(collectionGroup(vetA, 'events')));
  });

  it('validates clinic, link and assignee on staff-created events', async () => {
    const vetA = db('vetA');
    const ownerB = db('ownerB');
    const ok = { title: 'C', bookedByVetId: 'vetA', clinicId: A, vetId: 'vetA' };
    await assertSucceeds(setDoc(doc(vetA, 'users/clientA/events/e1'), ok));
    // wrong clinic for the staff member
    await assertFails(setDoc(doc(vetA, 'users/clientAB/events/e2'), { ...ok, clinicId: B }));
    // client not linked to that clinic
    await assertFails(setDoc(doc(ownerB, 'users/clientA/events/e3'), { ...ok, clinicId: B, bookedByVetId: 'ownerB', vetId: 'ownerB' }));
    // assignee not a member of the clinic
    await assertFails(setDoc(doc(vetA, 'users/clientA/events/e4'), { ...ok, vetId: 'ownerB' }));
    // spoofed bookedByVetId
    await assertFails(setDoc(doc(vetA, 'users/clientA/events/e5'), { ...ok, bookedByVetId: 'ownerA' }));
  });

  it('lets the owner create only personal events', async () => {
    const clientAB = db('clientAB');
    await assertSucceeds(setDoc(doc(clientAB, 'users/clientAB/events/mine'), { title: 'M' }));
    await assertFails(
      setDoc(doc(clientAB, 'users/clientAB/events/mine2'), { title: 'M', clinicId: A }),
    );
    await assertFails(
      setDoc(doc(clientAB, 'users/clientAB/events/mine3'), { title: 'M', bookedByVetId: 'vetA' }),
    );
  });

  it('lets staff edit own-clinic events and clients cancel vet-booked ones once', async () => {
    await seedEvents();
    const vetA = db('vetA');
    const ownerB = db('ownerB');
    const clientAB = db('clientAB');
    await assertSucceeds(updateDoc(doc(vetA, 'users/clientAB/events/evtA'), { title: 'C2' }));
    await assertFails(updateDoc(doc(vetA, 'users/clientAB/events/evtA'), { clinicId: B }));
    await assertFails(updateDoc(doc(vetA, 'users/clientAB/events/evtB'), { title: 'x' }));
    await assertFails(updateDoc(doc(ownerB, 'users/clientAB/events/personal'), { title: 'x' }));
    // client one-shot cancel on the vet-booked event
    await assertSucceeds(
      updateDoc(doc(clientAB, 'users/clientAB/events/evtA'), {
        cancelledAt: 2, cancelledBy: 'clientAB', cancelReason: 'Doente', updatedAt: 2,
      }),
    );
    await assertFails(
      updateDoc(doc(clientAB, 'users/clientAB/events/evtA'), {
        cancelledAt: 3, cancelledBy: 'clientAB', cancelReason: 'x', updatedAt: 3,
      }),
    );
    await assertFails(deleteDoc(doc(clientAB, 'users/clientAB/events/evtB')));
  });
});

/* -------------------------------- chat pool -------------------------------- */

describe('chat pool', () => {
  const poolRoom = () => ({
    petOwnerId: 'clientA',
    petOwnerName: 'Ana',
    clinicId: A,
    requestedVetId: null,
    vetId: null,
    vetName: null,
    status: 0,
    unreadCounts: {},
    isActive: true,
  });

  it('lets the client create pool and directed rooms within her clinics', async () => {
    const clientA = db('clientA');
    await assertSucceeds(setDoc(doc(clientA, 'chatRooms/pool'), poolRoom()));
    await assertSucceeds(
      setDoc(doc(clientA, 'chatRooms/direct'), {
        ...poolRoom(), requestedVetId: 'vetA', vetId: 'vetA', vetName: 'Dr. Vet', status: 1,
      }),
    );
    // can't direct to a non-member of the clinic
    await assertFails(
      setDoc(doc(clientA, 'chatRooms/bad1'), {
        ...poolRoom(), requestedVetId: 'ownerB', vetId: 'ownerB', status: 1,
      }),
    );
    // can't open a room in a clinic she's not linked to
    await assertFails(setDoc(doc(clientA, 'chatRooms/bad2'), { ...poolRoom(), clinicId: B }));
    // mismatched requestedVetId
    await assertFails(
      setDoc(doc(clientA, 'chatRooms/bad3'), { ...poolRoom(), requestedVetId: 'vetA', vetId: null }),
    );
  });

  it('lets staff create a room for a linked client', async () => {
    const vetA = db('vetA');
    const ownerB = db('ownerB');
    await assertSucceeds(
      setDoc(doc(vetA, 'chatRooms/staff'), {
        ...poolRoom(), vetId: 'vetA', vetName: 'Dr. Vet', status: 1,
      }),
    );
    await assertFails(
      setDoc(doc(ownerB, 'chatRooms/staff2'), {
        ...poolRoom(), petOwnerId: 'clientA', vetId: 'ownerB', clinicId: B, status: 1,
      }),
    );
  });

  it('pool room is visible to clinic vets, claim locks it to the claimant', async () => {
    await seed(async (d) => {
      await setDoc(doc(d, 'chatRooms/pool'), poolRoom());
      await setDoc(doc(d, 'chatRooms/pool/messages/m1'), {
        senderId: 'clientA', content: 'Olá', status: 0, isDeleted: false, metadata: null,
      });
    });
    const vetA = db('vetA');
    const ownerA = db('ownerA');
    const ownerB = db('ownerB');
    await assertSucceeds(getDoc(doc(vetA, 'chatRooms/pool')));
    await assertSucceeds(getDoc(doc(ownerA, 'chatRooms/pool')));
    await assertFails(getDoc(doc(ownerB, 'chatRooms/pool')));
    // pool list query
    const pool = query(
      collection(vetA, 'chatRooms'), where('clinicId', '==', A), where('vetId', '==', null),
    );
    await assertSucceeds(getDocs(pool));
    await assertFails(
      getDocs(query(collection(ownerB, 'chatRooms'), where('clinicId', '==', A), where('vetId', '==', null))),
    );
    // pool vet can read but not post
    await assertSucceeds(getDoc(doc(ownerA, 'chatRooms/pool/messages/m1')));
    await assertFails(
      addDoc(collection(ownerA, 'chatRooms/pool/messages'), { senderId: 'ownerA', content: 'x' }),
    );
    // claim
    await assertSucceeds(
      updateDoc(doc(vetA, 'chatRooms/pool'), {
        vetId: 'vetA', vetName: 'Dr. Vet', status: 1, claimedAt: 1,
      }),
    );
    // after claim: ownerA loses read + can't claim it (race lost)
    await assertFails(getDoc(doc(ownerA, 'chatRooms/pool')));
    await assertFails(
      updateDoc(doc(ownerA, 'chatRooms/pool'), { vetId: 'ownerA', vetName: 'O', status: 1 }),
    );
    // claimant can post now
    await assertSucceeds(
      addDoc(collection(vetA, 'chatRooms/pool/messages'), { senderId: 'vetA', content: 'oi' }),
    );
  });

  it('release puts the room back in the pool; only the assignee can release', async () => {
    await seed(async (d) => {
      await setDoc(doc(d, 'chatRooms/direct'), {
        ...poolRoom(), requestedVetId: 'vetA', vetId: 'vetA', vetName: 'Dr. Vet', status: 1,
      });
    });
    const vetA = db('vetA');
    const ownerA = db('ownerA');
    await assertFails(
      updateDoc(doc(ownerA, 'chatRooms/direct'), { vetId: null, vetName: null, status: 0 }),
    );
    await assertSucceeds(
      updateDoc(doc(vetA, 'chatRooms/direct'), {
        vetId: null, vetName: null, status: 0, releasedAt: 1,
      }),
    );
    // back in the pool: ownerA sees it again
    await assertSucceeds(getDoc(doc(ownerA, 'chatRooms/direct')));
  });

  it('keeps directed/assigned rooms private to owner + assignee', async () => {
    await seed(async (d) => {
      await setDoc(doc(d, 'chatRooms/direct'), {
        ...poolRoom(), requestedVetId: 'vetA', vetId: 'vetA', vetName: 'Dr. Vet', status: 1,
      });
      await setDoc(doc(d, 'chatRooms/direct/messages/m1'), {
        senderId: 'vetA', content: 'Olá', status: 0, isDeleted: false, metadata: null,
      });
    });
    const vetA = db('vetA');
    const ownerA = db('ownerA');
    const clientA = db('clientA');
    await assertSucceeds(getDoc(doc(vetA, 'chatRooms/direct')));
    await assertSucceeds(getDoc(doc(clientA, 'chatRooms/direct')));
    await assertFails(getDoc(doc(ownerA, 'chatRooms/direct')));
    await assertFails(getDoc(doc(ownerA, 'chatRooms/direct/messages/m1')));
    // assigned-vet room list + client room list
    await assertSucceeds(getDocs(query(collection(vetA, 'chatRooms'), where('vetId', '==', 'vetA'))));
    await assertSucceeds(
      getDocs(query(collection(clientA, 'chatRooms'), where('petOwnerId', '==', 'clientA'))),
    );
    await assertFails(
      getDocs(query(collection(ownerA, 'chatRooms'), where('vetId', '==', 'vetA'))),
    );
  });

  it('lets participants update activity fields only', async () => {
    await seed(async (d) => {
      await setDoc(doc(d, 'chatRooms/r1'), {
        ...poolRoom(), vetId: 'vetA', requestedVetId: 'vetA', status: 1,
      });
    });
    const clientA = db('clientA');
    await assertSucceeds(updateDoc(doc(clientA, 'chatRooms/r1'), { 'unreadCounts.clientA': 0 }));
    await assertFails(updateDoc(doc(clientA, 'chatRooms/r1'), { vetId: 'ownerA' }));
    await assertFails(updateDoc(doc(clientA, 'chatRooms/r1'), { petOwnerId: 'x' }));
    await assertFails(updateDoc(doc(clientA, 'chatRooms/r1'), { clinicId: B }));
  });
});

/* --------------------------- appointment requests -------------------------- */

describe('appointment request pool', () => {
  const req = () => ({
    petOwnerId: 'clientA',
    petOwnerName: 'Ana',
    clinicId: A,
    requestedVetId: null,
    vetId: null,
    status: 0,
    petId: 'luna',
    reason: 'Consulta',
    createdAt: 1,
  });

  it('lets the client create pool and directed requests in her clinics', async () => {
    const clientA = db('clientA');
    await assertSucceeds(setDoc(doc(clientA, 'appointmentRequests/pool'), req()));
    await assertSucceeds(
      setDoc(doc(clientA, 'appointmentRequests/direct'), {
        ...req(), requestedVetId: 'vetA', vetId: 'vetA',
      }),
    );
    await assertFails(
      setDoc(doc(clientA, 'appointmentRequests/bad1'), {
        ...req(), requestedVetId: 'ownerB', vetId: 'ownerB',
      }),
    );
    await assertFails(
      setDoc(doc(clientA, 'appointmentRequests/bad2'), { ...req(), clinicId: B }),
    );
    await assertFails(
      setDoc(doc(clientA, 'appointmentRequests/bad3'), { ...req(), status: 1 }),
    );
    // client sees her own requests
    await assertSucceeds(
      getDocs(
        query(collection(clientA, 'appointmentRequests'), where('petOwnerId', '==', 'clientA')),
      ),
    );
  });

  it('claim by confirm/deny assigns to the first vet; the loser fails', async () => {
    await seed(async (d) => {
      await setDoc(doc(d, 'appointmentRequests/pool'), req());
    });
    const vetA = db('vetA');
    const ownerA = db('ownerA');
    const ownerB = db('ownerB');
    // pool visible to clinic vets, list query works
    await assertSucceeds(getDoc(doc(vetA, 'appointmentRequests/pool')));
    await assertFails(getDoc(doc(ownerB, 'appointmentRequests/pool')));
    await assertSucceeds(
      getDocs(
        query(collection(vetA, 'appointmentRequests'), where('clinicId', '==', A), where('vetId', '==', null)),
      ),
    );
    // vetA claims by confirming
    await assertSucceeds(
      updateDoc(doc(vetA, 'appointmentRequests/pool'), {
        vetId: 'vetA', status: 1, handledBy: 'vetA', handledAt: 2, bookedDateTime: 3, updatedAt: 2,
      }),
    );
    // ownerA lost the race — can no longer see or claim it
    await assertFails(getDoc(doc(ownerA, 'appointmentRequests/pool')));
    await assertFails(
      updateDoc(doc(ownerA, 'appointmentRequests/pool'), {
        vetId: 'ownerA', status: 1, handledBy: 'ownerA', handledAt: 2,
      }),
    );
  });

  it('claimer can only touch handling fields — not reason/pet/identity', async () => {
    await seed(async (d) => {
      await setDoc(doc(d, 'appointmentRequests/pool'), req());
      await setDoc(doc(d, 'appointmentRequests/pool2'), req());
      await setDoc(doc(d, 'appointmentRequests/pool3'), req());
    });
    const vetA = db('vetA');
    await assertFails(
      updateDoc(doc(vetA, 'appointmentRequests/pool'), {
        vetId: 'vetA', status: 1, handledBy: 'vetA', handledAt: 2, reason: 'Urgência',
      }),
    );
    await assertFails(
      updateDoc(doc(vetA, 'appointmentRequests/pool2'), {
        vetId: 'vetA', status: 1, handledBy: 'vetA', handledAt: 2, petId: 'rex',
      }),
    );
    await assertFails(
      updateDoc(doc(vetA, 'appointmentRequests/pool3'), {
        vetId: 'vetA', status: 1, handledBy: 'vetA', handledAt: 2, petOwnerName: 'Outra',
      }),
    );
    // a clean claim still succeeds
    await assertSucceeds(
      updateDoc(doc(vetA, 'appointmentRequests/pool'), {
        vetId: 'vetA', status: 1, handledBy: 'vetA', handledAt: 2, bookedDateTime: 3, updatedAt: 2,
      }),
    );
  });

  it('pool request can be claimed by denial too', async () => {
    await seed(async (d) => {
      await setDoc(doc(d, 'appointmentRequests/pool'), req());
    });
    const ownerA = db('ownerA');
    await assertSucceeds(
      updateDoc(doc(ownerA, 'appointmentRequests/pool'), {
        vetId: 'ownerA', status: 2, handledBy: 'ownerA', handledAt: 2, responseMessage: 'Sem vagas',
      }),
    );
  });

  it('assignee handles own requests; release only while pending; directed stays private', async () => {
    await seed(async (d) => {
      await setDoc(doc(d, 'appointmentRequests/direct'), {
        ...req(), requestedVetId: 'vetA', vetId: 'vetA',
      });
      await setDoc(doc(d, 'appointmentRequests/done'), {
        ...req(), requestedVetId: 'vetA', vetId: 'vetA', status: 1,
      });
    });
    const vetA = db('vetA');
    const ownerA = db('ownerA');
    // directed to vetA is invisible to ownerA
    await assertFails(getDoc(doc(ownerA, 'appointmentRequests/direct')));
    await assertSucceeds(getDoc(doc(vetA, 'appointmentRequests/direct')));
    // vetA updates status/handling fields
    await assertSucceeds(
      updateDoc(doc(vetA, 'appointmentRequests/direct'), { status: 1, handledBy: 'vetA', handledAt: 2, bookedDateTime: 3 }),
    );
    // but can't touch identity fields
    await seed(async (d) => {
      await setDoc(doc(d, 'appointmentRequests/direct2'), { ...req(), requestedVetId: 'vetA', vetId: 'vetA' });
    });
    await assertFails(
      updateDoc(doc(vetA, 'appointmentRequests/direct2'), { petOwnerId: 'clientAB' }),
    );
    // release pending → back to pool
    await assertSucceeds(
      updateDoc(doc(vetA, 'appointmentRequests/direct2'), { vetId: null, updatedAt: 2 }),
    );
    // release+confirm in a single write → denied (would leave a confirmed request with no vet)
    await seed(async (d) => {
      await setDoc(doc(d, 'appointmentRequests/direct3'), { ...req(), requestedVetId: 'vetA', vetId: 'vetA' });
    });
    await assertFails(
      updateDoc(doc(vetA, 'appointmentRequests/direct3'), {
        vetId: null, status: 1, handledBy: 'vetA', handledAt: 2, updatedAt: 2,
      }),
    );
    // release confirmed → denied
    await assertFails(
      updateDoc(doc(vetA, 'appointmentRequests/done'), { vetId: null, updatedAt: 2 }),
    );
    // ownerA can't update vetA's request
    await assertFails(
      updateDoc(doc(ownerA, 'appointmentRequests/done'), { status: 2 }),
    );
  });

  it('lets the client delete a pending request only', async () => {
    await seed(async (d) => {
      await setDoc(doc(d, 'appointmentRequests/p'), req());
      await setDoc(doc(d, 'appointmentRequests/c'), { ...req(), status: 1, vetId: 'vetA' });
    });
    const clientA = db('clientA');
    const ownerB = db('ownerB');
    await assertSucceeds(deleteDoc(doc(clientA, 'appointmentRequests/p')));
    await assertFails(deleteDoc(doc(clientA, 'appointmentRequests/c')));
    await assertFails(deleteDoc(doc(ownerB, 'appointmentRequests/c')));
  });
});

/* --------------------------------- clinics -------------------------------- */

describe('clinic docs', () => {
  it('member + linked client can get the clinic; nobody can list', async () => {
    const vetA = db('vetA');
    const clientA = db('clientA');
    const pendingB = db('pendingB');
    const stranger = db('stranger');
    await assertSucceeds(getDoc(doc(vetA, `clinics/${A}`)));
    await assertSucceeds(getDoc(doc(clientA, `clinics/${A}`)));
    // pending link → no clinic read
    await assertFails(getDoc(doc(pendingB, `clinics/${B}`)));
    await assertSucceeds(getDoc(doc(pendingB, `clinics/${A}`)));
    await assertFails(getDoc(doc(stranger, `clinics/${A}`)));
    await assertFails(getDocs(collection(vetA, 'clinics')));
  });

  it('only an owner can update brand/name/contact', async () => {
    const ownerA = db('ownerA');
    const vetA = db('vetA');
    await assertSucceeds(
      updateDoc(doc(ownerA, `clinics/${A}`), { 'brand.primary': '#FA5119', updatedAt: 2 }),
    );
    await assertFails(updateDoc(doc(ownerA, `clinics/${A}`), { isActive: false }));
    await assertFails(updateDoc(doc(vetA, `clinics/${A}`), { 'brand.primary': '#000' }));
    await assertFails(setDoc(doc(ownerA, 'clinics/new'), { name: 'X' }));
    await assertFails(deleteDoc(doc(ownerA, `clinics/${A}`)));
  });

  it('member/client subcollections are read-only and scoped', async () => {
    const vetA = db('vetA');
    const clientA = db('clientA');
    const pendingB = db('pendingB');
    const ownerB = db('ownerB');
    // roster readable by members and linked clients
    await assertSucceeds(getDoc(doc(vetA, `clinics/${A}/members/vetA`)));
    await assertSucceeds(getDoc(doc(clientA, `clinics/${A}/members/vetA`)));
    await assertFails(getDoc(doc(clientA, `clinics/${B}/members/ownerB`)));
    await assertSucceeds(getDocs(collection(clientA, `clinics/${A}/members`)));
    // link docs: staff see all (filtered list), a client only their own
    await assertSucceeds(
      getDocs(query(collection(vetA, `clinics/${A}/clients`), where('status', '==', 'active'))),
    );
    await assertSucceeds(getDoc(doc(pendingB, `clinics/${B}/clients/pendingB`)));
    await assertFails(getDoc(doc(clientA, `clinics/${A}/clients/clientA2`)));
    await assertFails(getDoc(doc(ownerB, `clinics/${A}/clients/clientA`)));
    // nobody writes either subcollection
    await assertFails(setDoc(doc(vetA, `clinics/${A}/members/x`), member('vet')));
    await assertFails(setDoc(doc(vetA, `clinics/${A}/clients/x`), link('x', 'Clinic A', 'active')));
  });

  it('client lists their own link docs (incl. pending) via collection group', async () => {
    const pendingB = db('pendingB');
    await assertSucceeds(
      getDocs(query(collectionGroup(pendingB, 'clients'), where('clientId', '==', 'pendingB'))),
    );
    const clientA = db('clientA');
    await assertFails(
      getDocs(query(collectionGroup(clientA, 'clients'), where('clientId', '==', 'pendingB'))),
    );
    await assertFails(getDocs(collectionGroup(clientA, 'clients')));
  });

  it('legacy clinic members without memberOf get nothing', async () => {
    const legacy = db('legacyUser');
    await assertFails(getDoc(doc(legacy, `clinics/${LEGACY}`)));
    await assertFails(getDoc(doc(legacy, `clinics/${LEGACY}/members/legacyUser`)));
    await assertFails(getDocs(collection(legacy, `clinics/${LEGACY}/members`)));
  });
});

/* --------------------------------- pet tags -------------------------------- */

describe('pet tag rules', () => {
  const tag = { ownerId: 'clientA', petId: 'luna', petName: 'Luna', species: 'Cão' };

  const seedPet = () =>
    seed((d) => setDoc(doc(d, 'users/clientA/pets/luna'), { name: 'Luna' }));

  const seedTag = (id = 'luna', data: object = tag) =>
    seed((d) => setDoc(doc(d, `petTags/${id}`), data));

  it('lets anyone read one tag by id but not list the collection', async () => {
    await seedTag();
    const a = anon();
    await assertSucceeds(getDoc(doc(a, 'petTags/luna')));
    await assertFails(getDocs(collection(a, 'petTags')));
  });

  it('lets the owner create, blocks others and spoofs', async () => {
    await seedPet();
    const clientA = db('clientA');
    const vetA = db('vetA');
    await assertSucceeds(setDoc(doc(clientA, 'petTags/luna'), tag));
    await assertFails(setDoc(doc(vetA, 'petTags/rex'), { ...tag, petId: 'rex' }));
    await assertFails(setDoc(doc(clientA, 'petTags/x'), { ...tag, ownerId: 'clientA2' }));
    await assertFails(setDoc(doc(clientA, 'petTags/ghost'), { ...tag, petId: 'ghost' }));
  });

  it('lets clinic staff write pet fields but never the contact choice', async () => {
    await seedPet();
    const vetA = db('vetA');
    const ownerB = db('ownerB');
    await assertSucceeds(
      setDoc(doc(vetA, 'petTags/luna'), { ...tag, showContact: false, contactName: null, contactPhone: null }),
    );
    await assertSucceeds(updateDoc(doc(vetA, 'petTags/luna'), { petName: 'Luninha' }));
    await assertFails(updateDoc(doc(vetA, 'petTags/luna'), { contactPhone: '910000000' }));
    await assertFails(updateDoc(doc(vetA, 'petTags/luna'), { showContact: true }));
    await assertFails(setDoc(doc(ownerB, 'petTags/rex'), { ...tag, petId: 'rex', showContact: false }));
    await assertFails(updateDoc(doc(ownerB, 'petTags/luna'), { petName: 'x' }));
  });
});

/* ------------------------------- gcal -------------------------------------- */

describe('gcal sync rules', () => {
  it('lets the vet read her own gcalStatus and nobody else', async () => {
    await seed((d) => setDoc(doc(d, 'gcalStatus/vetA'), { connected: true }));
    const vetA = db('vetA');
    const ownerB = db('ownerB');
    const clientA = db('clientA');
    await assertSucceeds(getDoc(doc(vetA, 'gcalStatus/vetA')));
    await assertFails(getDoc(doc(ownerB, 'gcalStatus/vetA')));
    await assertFails(getDoc(doc(clientA, 'gcalStatus/vetA')));
  });

  it('blocks all writes to gcalStatus and all access to gcalTokens', async () => {
    await seed(async (d) => {
      await setDoc(doc(d, 'gcalTokens/vetA'), { refreshToken: 'r' });
    });
    const vetA = db('vetA');
    await assertFails(updateDoc(doc(vetA, 'gcalStatus/vetA'), { connected: false }));
    await assertFails(getDoc(doc(vetA, 'gcalTokens/vetA')));
    await assertFails(setDoc(doc(vetA, 'gcalTokens/x'), { refreshToken: 'r' }));
  });
});

/* ----------------------------- found reports ------------------------------- */

describe('found report rules', () => {
  const report = () => ({
    ownerId: 'clientA',
    petId: 'luna',
    petName: 'Luna',
    finderName: 'Zé',
    finderContact: '910000000',
    message: 'Encontrei-a na rua',
    resolved: false,
    createdAt: serverTimestamp(),
  });

  const seedTag = () =>
    seed((d) =>
      setDoc(doc(d, 'petTags/luna'), { ownerId: 'clientA', petId: 'luna', petName: 'Luna' }),
    );

  const seedReport = () =>
    seed((d) =>
      setDoc(doc(d, 'petTags/luna/foundReports/r1'), {
        ownerId: 'clientA', petId: 'luna', finderContact: '910000000', resolved: false,
      }),
    );

  it('lets anyone create a valid report and reads only for the owner', async () => {
    await seedTag();
    const a = anon();
    const clientA = db('clientA');
    const vetA = db('vetA');
    const ref = doc(a, 'petTags/luna/foundReports/r2');
    await assertSucceeds(setDoc(ref, report()));
    await assertSucceeds(setDoc(doc(a, 'petTags/luna/foundReports/r3'), { ...report(), finderContact: 'a@b.pt' }));
    await assertFails(getDoc(doc(a, ref.path)));
    await assertFails(getDoc(doc(vetA, ref.path)));
    await assertSucceeds(getDoc(doc(clientA, ref.path)));
    await assertSucceeds(
      getDocs(query(collectionGroup(clientA, 'foundReports'), where('ownerId', '==', 'clientA'))),
    );
  });

  it('rejects forged or malformed reports', async () => {
    await seedTag();
    const a = anon();
    const col = collection(a, 'petTags/luna/foundReports');
    await assertFails(addDoc(col, { ...report(), ownerId: 'clientA2' }));
    await assertFails(addDoc(col, { ...report(), extra: 'x' }));
    await assertFails(addDoc(col, { ...report(), finderContact: 'ab' }));
    await assertFails(addDoc(col, { ...report(), resolved: true }));
    await assertFails(addDoc(collection(a, 'petTags/ghost/foundReports'), report()));
  });

  it('lets the owner resolve but not edit the report', async () => {
    await seedTag();
    await seedReport();
    const clientA = db('clientA');
    const ref = doc(clientA, 'petTags/luna/foundReports/r1');
    await assertSucceeds(updateDoc(ref, { resolved: true }));
    await assertFails(updateDoc(ref, { message: 'editado' }));
  });
});
