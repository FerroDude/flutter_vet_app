import { doc, setDoc } from 'firebase/firestore';
import { db } from './firebase';

export interface PrivateNotes {
  text: string;
  updatedAt: Date | null;
  updatedBy: string | null;
}

export function privateNotesDoc(clientId: string, petId: string) {
  return doc(db, 'users', clientId, 'pets', petId, 'private', 'notes');
}

export function mapPrivateNotes(_id: string, data: Record<string, unknown>): PrivateNotes {
  const updatedAt = data.updatedAt;
  return {
    text: (data.text as string) ?? '',
    updatedAt:
      typeof updatedAt === 'number'
        ? new Date(updatedAt)
        : updatedAt && typeof (updatedAt as { toDate?: () => Date }).toDate === 'function'
          ? (updatedAt as { toDate: () => Date }).toDate()
          : null,
    updatedBy: (data.updatedBy as string | null) ?? null,
  };
}

export async function savePrivateNotes(args: {
  clientId: string;
  petId: string;
  text: string;
  vetId: string;
}): Promise<void> {
  await setDoc(
    privateNotesDoc(args.clientId, args.petId),
    {
      text: args.text,
      updatedAt: Date.now(),
      updatedBy: args.vetId,
    },
    { merge: true },
  );
}
