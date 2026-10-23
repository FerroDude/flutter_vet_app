// Vet-only notes on a pet. Each note is one doc in
// users/{clientId}/pets/{petId}/private/{noteId}; rules hide the collection
// from the client. The legacy single doc (id "notes") reads as one note.

import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  query,
  updateDoc,
  type DocumentData,
} from 'firebase/firestore';
import { db } from './firebase';

export interface PrivateNote {
  id: string;
  text: string;
  createdAt: Date | null;
  updatedAt: Date | null;
  updatedBy: string | null;
}

const notesCol = (clientId: string, petId: string) =>
  collection(db, 'users', clientId, 'pets', petId, 'private');

export function privateNotesQuery(clientId: string, petId: string) {
  return query(notesCol(clientId, petId));
}

function toDate(v: unknown): Date | null {
  if (typeof v === 'number') return new Date(v);
  if (v && typeof (v as { toDate?: () => Date }).toDate === 'function') {
    return (v as { toDate: () => Date }).toDate();
  }
  return null;
}

export function mapPrivateNote(id: string, data: DocumentData): PrivateNote {
  const updatedAt = toDate(data.updatedAt);
  return {
    id,
    text: (data.text as string) ?? '',
    createdAt: toDate(data.createdAt) ?? updatedAt,
    updatedAt,
    updatedBy: (data.updatedBy as string | null) ?? null,
  };
}

export async function addPrivateNote(args: {
  clientId: string;
  petId: string;
  text: string;
  vetId: string;
}): Promise<void> {
  const now = Date.now();
  await addDoc(notesCol(args.clientId, args.petId), {
    text: args.text,
    createdAt: now,
    updatedAt: now,
    updatedBy: args.vetId,
  });
}

export async function updatePrivateNote(args: {
  clientId: string;
  petId: string;
  noteId: string;
  text: string;
  vetId: string;
}): Promise<void> {
  await updateDoc(doc(notesCol(args.clientId, args.petId), args.noteId), {
    text: args.text,
    updatedAt: Date.now(),
    updatedBy: args.vetId,
  });
}

export async function deletePrivateNote(clientId: string, petId: string, noteId: string): Promise<void> {
  await deleteDoc(doc(notesCol(clientId, petId), noteId));
}
