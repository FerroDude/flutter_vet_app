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

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-vetplus',
    firestore: { rules, host: '127.0.0.1', port: 8080 },
  });
});

afterAll(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/vet'), {
      email: 'vet@example.com',
      displayName: 'Dra. Silva',
      userType: 1,
      phone: '210000000',
      address: 'Rua das Flores 1',
      vetId: null,
    });
    await setDoc(doc(db, 'users/client'), {
      email: 'ana@example.com',
      displayName: 'Ana',
      userType: 0,
      vetId: 'vet',
    });
    await setDoc(doc(db, 'users/other'), {
      email: 'other@example.com',
      displayName: 'Outra',
      userType: 1,
      vetId: null,
    });
  });
});

describe('solo vet rules', () => {
  it('lets the client read their own pet and blocks another vet', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users/client/pets/luna'), { name: 'Luna' });
    });
    const client = env.authenticatedContext('client').firestore();
    const other = env.authenticatedContext('other').firestore();
    await assertSucceeds(getDoc(doc(client, 'users/client/pets/luna')));
    await assertFails(getDoc(doc(other, 'users/client/pets/luna')));
  });

  it('hides private notes from the client and shows them to her vet', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users/client/pets/luna/private/notes'), {
        text: 'secreto',
      });
    });
    const client = env.authenticatedContext('client').firestore();
    const vet = env.authenticatedContext('vet').firestore();
    await assertFails(getDoc(doc(client, 'users/client/pets/luna/private/notes')));
    await assertSucceeds(getDoc(doc(vet, 'users/client/pets/luna/private/notes')));
  });

  it('lets the vet add and list several private notes, hidden from the client', async () => {
    const vet = env.authenticatedContext('vet').firestore();
    const client = env.authenticatedContext('client').firestore();
    const notes = collection(vet, 'users/client/pets/luna/private');
    await assertSucceeds(addDoc(notes, { text: 'Primeira' }));
    await assertSucceeds(addDoc(notes, { text: 'Segunda' }));
    await assertSucceeds(getDocs(notes));
    await assertFails(getDocs(collection(client, 'users/client/pets/luna/private')));
  });

  it('stops the client changing vetId', async () => {
    const client = env.authenticatedContext('client').firestore();
    await assertFails(updateDoc(doc(client, 'users/client'), { vetId: 'other' }));
  });

  it('lets the client read the vet address and not another client', async () => {
    const client = env.authenticatedContext('client').firestore();
    await assertSucceeds(getDoc(doc(client, 'users/vet')));
    await assertFails(getDoc(doc(client, 'users/other')));
  });

  it('lets the vet write a calendar event and blocks the client from deleting it', async () => {
    const vet = env.authenticatedContext('vet').firestore();
    const client = env.authenticatedContext('client').firestore();
    await assertSucceeds(
      setDoc(doc(vet, 'users/client/events/visita'), {
        title: 'Consulta',
        bookedByVetId: 'vet',
        userId: 'client',
      }),
    );
    await assertFails(deleteDoc(doc(client, 'users/client/events/visita')));
  });

  it('lets the vet list her booked appointments across clients, and nobody else', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users/client/events/a1'), { bookedByVetId: 'vet', title: 'Consulta' });
      await setDoc(doc(db, 'users/client/events/a2'), { bookedByVetId: 'other', title: 'Outra' });
    });
    const vet = env.authenticatedContext('vet').firestore();
    const other = env.authenticatedContext('other').firestore();
    const mine = query(collectionGroup(vet, 'events'), where('bookedByVetId', '==', 'vet'));
    await assertSucceeds(getDocs(mine));
    await assertFails(getDocs(collectionGroup(vet, 'events')));
    await assertFails(
      getDocs(query(collectionGroup(other, 'events'), where('bookedByVetId', '==', 'vet'))),
    );
  });

  it('lets the vet book an appointment in her client calendar', async () => {
    const vet = env.authenticatedContext('vet').firestore();
    const other = env.authenticatedContext('other').firestore();
    await assertSucceeds(
      setDoc(doc(vet, 'users/client/events/novo'), { bookedByVetId: 'vet', userId: 'client' }),
    );
    await assertFails(
      setDoc(doc(other, 'users/client/events/x'), { bookedByVetId: 'other', userId: 'client' }),
    );
  });

  it('blocks self-created profiles and lets the vet create a client', async () => {
    const stranger = env.authenticatedContext('stranger').firestore();
    const vet = env.authenticatedContext('vet').firestore();
    await assertFails(setDoc(doc(stranger, 'users/stranger'), { userType: 0, vetId: null }));
    await assertFails(setDoc(doc(stranger, 'users/stranger'), { userType: 1, vetId: null }));
    await assertSucceeds(setDoc(doc(vet, 'users/novo'), { userType: 0, vetId: 'vet' }));
    await assertFails(setDoc(doc(vet, 'users/outro'), { userType: 1, vetId: 'vet' }));
  });

  it('lets a legacy profile without vetId update itself', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users/legacy'), { userType: 1, displayName: 'Old' });
    });
    const legacy = env.authenticatedContext('legacy').firestore();
    await assertSucceeds(updateDoc(doc(legacy, 'users/legacy'), { fcmToken: 't' }));
    await assertFails(updateDoc(doc(legacy, 'users/legacy'), { vetId: 'vet' }));
  });
});

describe('client cancels a vet-booked appointment', () => {
  const seed = (id: string) =>
    env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), `users/client/events/${id}`), {
        bookedByVetId: 'vet',
        userId: 'client',
        title: 'Consulta',
        dateTime: 1,
        cancelledAt: null,
      }),
    );

  it('lets the client cancel once with a reason, then blocks a second cancel', async () => {
    await seed('v1');
    const client = env.authenticatedContext('client').firestore();
    await assertSucceeds(
      updateDoc(doc(client, 'users/client/events/v1'), {
        cancelledAt: 2,
        cancelledBy: 'client',
        cancelReason: 'Doente',
        updatedAt: 2,
      }),
    );
    await assertFails(
      updateDoc(doc(client, 'users/client/events/v1'), {
        cancelledAt: 3,
        cancelledBy: 'client',
        cancelReason: 'Mudei de ideias',
        updatedAt: 3,
      }),
    );
  });

  it('rejects cancels without reason, with extra changes, or as someone else', async () => {
    await seed('v2');
    const client = env.authenticatedContext('client').firestore();
    const ev = doc(client, 'users/client/events/v2');
    await assertFails(
      updateDoc(ev, { cancelledAt: 2, cancelledBy: 'client', cancelReason: '', updatedAt: 2 }),
    );
    await assertFails(
      updateDoc(ev, {
        cancelledAt: 2,
        cancelledBy: 'client',
        cancelReason: 'Doente',
        updatedAt: 2,
        dateTime: 9,
      }),
    );
    await assertFails(
      updateDoc(ev, { cancelledAt: 2, cancelledBy: 'other', cancelReason: 'Doente', updatedAt: 2 }),
    );
    await assertFails(deleteDoc(ev));
  });

  it('still lets the vet update the event', async () => {
    await seed('v3');
    const vet = env.authenticatedContext('vet').firestore();
    await assertSucceeds(
      updateDoc(doc(vet, 'users/client/events/v3'), { title: 'Consulta de seguimento', updatedAt: 2 }),
    );
  });
});

describe('chat rules', () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'chatRooms/r1'), {
        petOwnerId: 'client',
        vetId: 'vet',
        unreadCounts: {},
        isActive: true,
        status: 0,
      });
      await setDoc(doc(db, 'chatRooms/r1/messages/m1'), {
        senderId: 'vet',
        content: 'Olá',
        status: 0,
        metadata: null,
        isDeleted: false,
      });
    });
  });

  it('lets participants update activity fields only', async () => {
    const client = env.authenticatedContext('client').firestore();
    await assertSucceeds(updateDoc(doc(client, 'chatRooms/r1'), { 'unreadCounts.client': 0 }));
    await assertFails(updateDoc(doc(client, 'chatRooms/r1'), { vetId: 'other' }));
    await assertFails(updateDoc(doc(client, 'chatRooms/r1'), { petOwnerId: 'x' }));
  });

  it('lets the sender delete, the recipient mark read, and nobody edit content', async () => {
    const client = env.authenticatedContext('client').firestore();
    const vet = env.authenticatedContext('vet').firestore();
    const m = 'chatRooms/r1/messages/m1';
    await assertFails(updateDoc(doc(client, m), { content: 'editado' }));
    await assertFails(updateDoc(doc(vet, m), { content: 'editado' }));
    await assertFails(updateDoc(doc(client, m), { isDeleted: true }));
    await assertSucceeds(updateDoc(doc(client, m), { status: 2, readAt: 1 }));
    await assertSucceeds(updateDoc(doc(vet, m), { isDeleted: true, deletedAt: 1 }));
  });

  it('allows reactions but not other metadata changes', async () => {
    const client = env.authenticatedContext('client').firestore();
    const m = 'chatRooms/r1/messages/m1';
    await assertSucceeds(
      updateDoc(doc(client, m), {
        metadata: { reactions: [{ emoji: '👍', userIds: ['client'], userNames: ['Ana'] }] },
      }),
    );
    await assertFails(updateDoc(doc(client, m), { metadata: { replyToContent: 'x' } }));
  });
});

describe('pet tag rules', () => {
  const tag = { ownerId: 'client', petId: 'luna', petName: 'Luna', species: 'Cão' };

  const seedPet = () =>
    env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'users/client/pets/luna'), { name: 'Luna' }),
    );

  const seedTag = (id = 'luna', data: object = tag) =>
    env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), `petTags/${id}`), data),
    );

  it('lets anyone read one tag by id but not list the collection', async () => {
    await seedTag();
    const anon = env.unauthenticatedContext().firestore();
    await assertSucceeds(getDoc(doc(anon, 'petTags/luna')));
    await assertFails(getDocs(collection(anon, 'petTags')));
  });

  it('lets the owner create a tag for their own pet', async () => {
    await seedPet();
    const client = env.authenticatedContext('client').firestore();
    await assertSucceeds(setDoc(doc(client, 'petTags/luna'), tag));
  });

  it('blocks another user, an ownerId spoof, and a pet the owner does not have', async () => {
    await seedPet();
    const other = env.authenticatedContext('other').firestore();
    const client = env.authenticatedContext('client').firestore();
    await assertFails(setDoc(doc(other, 'petTags/luna'), tag));
    await assertFails(setDoc(doc(client, 'petTags/luna'), { ...tag, ownerId: 'other' }));
    await assertFails(setDoc(doc(client, 'petTags/ghost'), { ...tag, petId: 'ghost' }));
  });

  it('lets the owner update, blocks changing ownerId, and blocks other writers', async () => {
    await seedTag();
    const client = env.authenticatedContext('client').firestore();
    const other = env.authenticatedContext('other').firestore();
    await assertSucceeds(updateDoc(doc(client, 'petTags/luna'), { petName: 'Luninha' }));
    await assertFails(updateDoc(doc(client, 'petTags/luna'), { ownerId: 'other' }));
    await assertFails(updateDoc(doc(other, 'petTags/luna'), { petName: 'x' }));
    await assertFails(deleteDoc(doc(other, 'petTags/luna')));
    await assertSucceeds(deleteDoc(doc(client, 'petTags/luna')));
  });
});

describe('found report rules', () => {
  const report = () => ({
    ownerId: 'client',
    petId: 'luna',
    petName: 'Luna',
    finderName: 'Zé',
    finderContact: '910000000',
    message: 'Encontrei-a na rua',
    resolved: false,
    createdAt: serverTimestamp(),
  });

  const seedTag = () =>
    env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'petTags/luna'), {
        ownerId: 'client',
        petId: 'luna',
        petName: 'Luna',
      }),
    );

  const seedReport = () =>
    env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'petTags/luna/foundReports/r1'), {
        ownerId: 'client',
        petId: 'luna',
        finderContact: '910000000',
        resolved: false,
      }),
    );

  it('lets anyone create a valid report and reads only for the owner', async () => {
    await seedTag();
    const anon = env.unauthenticatedContext().firestore();
    const client = env.authenticatedContext('client').firestore();
    const other = env.authenticatedContext('other').firestore();
    const ref = doc(anon, 'petTags/luna/foundReports/r2');
    await assertSucceeds(setDoc(ref, report()));
    await assertFails(getDoc(doc(anon, ref.path)));
    await assertFails(getDoc(doc(other, ref.path)));
    await assertSucceeds(getDoc(doc(client, ref.path)));
    await assertSucceeds(
      getDocs(query(collectionGroup(client, 'foundReports'), where('ownerId', '==', 'client'))),
    );
  });

  it('rejects forged, malformed or resolved-at-creation reports', async () => {
    await seedTag();
    const anon = env.unauthenticatedContext().firestore();
    const col = collection(anon, 'petTags/luna/foundReports');
    await assertFails(addDoc(col, { ...report(), ownerId: 'other' }));
    await assertFails(addDoc(col, { ...report(), extra: 'x' }));
    await assertFails(addDoc(col, { ...report(), finderContact: 'ab' }));
    await assertFails(addDoc(col, { ...report(), resolved: true }));
    await assertFails(addDoc(collection(anon, 'petTags/ghost/foundReports'), report()));
  });

  it('lets the owner resolve but not edit the report', async () => {
    await seedTag();
    await seedReport();
    const client = env.authenticatedContext('client').firestore();
    const ref = doc(client, 'petTags/luna/foundReports/r1');
    await assertSucceeds(updateDoc(ref, { resolved: true }));
    await assertFails(updateDoc(ref, { message: 'editado' }));
  });
});
