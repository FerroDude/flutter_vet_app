// Notes on a pet. Each note is one doc in
// users/{clientId}/pets/{petId}/{private|publicNotes}/{noteId}. Private notes
// are vet-only; public notes are written by the vet and readable by the owner.
// The legacy single doc (id "notes") reads as one note.

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

export type NoteKind = 'private' | 'public';

export interface PrivateNote {
  id: string;
  text: string;
  createdAt: Date | null;
  updatedAt: Date | null;
  updatedBy: string | null;
}

const notesCol = (clientId: string, petId: string, kind: NoteKind = 'private') =>
  collection(db, 'users', clientId, 'pets', petId, kind === 'public' ? 'publicNotes' : 'private');

export function privateNotesQuery(clientId: string, petId: string, kind: NoteKind = 'private') {
  return query(notesCol(clientId, petId, kind));
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
  kind?: NoteKind;
}): Promise<void> {
  const now = Date.now();
  await addDoc(notesCol(args.clientId, args.petId, args.kind), {
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
  kind?: NoteKind;
}): Promise<void> {
  await updateDoc(doc(notesCol(args.clientId, args.petId, args.kind), args.noteId), {
    text: args.text,
    updatedAt: Date.now(),
    updatedBy: args.vetId,
  });
}

export async function deletePrivateNote(
  clientId: string,
  petId: string,
  noteId: string,
  kind: NoteKind = 'private',
): Promise<void> {
  await deleteDoc(doc(notesCol(clientId, petId, kind), noteId));
}
