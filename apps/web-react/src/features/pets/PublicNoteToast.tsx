import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { onSnapshot } from 'firebase/firestore';
import { useAuth } from '@/auth/AuthProvider';
import { petsQuery, mapPet } from '@/lib/petService';
import { privateNotesQuery, mapPrivateNote } from '@/lib/privateNotes';
import { clip, showAlert } from '@/features/chat/incomingMessage';
import { t } from '@/i18n';

/** Always-on alert when the vet adds a public note to one of the client's
 *  pets. No collection-group index exists, so it mirrors useAllMedications:
 *  one pets listener plus a per-pet publicNotes listener. Each pet listener
 *  baselines its own first snapshot, then toasts each new note. */
export function PublicNoteToast() {
  const { firebaseUser } = useAuth();
  const navigate = useNavigate();
  const uid = firebaseUser?.uid ?? '';

  useEffect(() => {
    if (!uid) return;

    const names = new Map<string, string>();
    const unsubs = new Map<string, () => void>();
    const baselined = new Set<string>();

    const unsubPets = onSnapshot(petsQuery(uid), (snap) => {
      const ids = new Set(snap.docs.map((d) => d.id));
      for (const [pid, unsub] of unsubs) {
        if (!ids.has(pid)) {
          unsub();
          unsubs.delete(pid);
          names.delete(pid);
          baselined.delete(pid);
        }
      }

      snap.docs.forEach((petDoc) => {
        const pid = petDoc.id;
        names.set(pid, mapPet(pid, petDoc.data()).name);
        if (unsubs.has(pid)) return;
        const unsub = onSnapshot(privateNotesQuery(uid, pid, 'public'), (noteSnap) => {
          if (!baselined.has(pid)) {
            baselined.add(pid);
            return;
          }
          for (const change of noteSnap.docChanges()) {
            if (change.type !== 'added' || change.doc.metadata.hasPendingWrites) continue;
            const note = mapPrivateNote(change.doc.id, change.doc.data());
            if (!note.text.trim()) continue;
            const title = t('notes.newToast', { pet: names.get(pid) || t('common.pet') });
            const description = clip(note.text);
            const open = () => navigate(`/pets/${pid}`);
            showAlert({
              id: `pubnote-${pid}-${note.id}`,
              title,
              description,
              open,
            });
          }
        });
        unsubs.set(pid, unsub);
      });
    });

    return () => {
      unsubPets();
      unsubs.forEach((u) => u());
    };
  }, [uid, navigate]);

  return null;
}
