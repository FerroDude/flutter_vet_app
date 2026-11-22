// Clinics (VetTempo): the clinic doc, its staff roster and the client links.
// clinics/{clinicId}         — name, brand, contact (get-only for members/clients)
// clinics/{clinicId}/members — staff roster (server-written)
// clinics/{clinicId}/clients — client links: pending | active | declined (server-written)

import { useEffect, useMemo, useState } from 'react';
import { collection, doc, getDoc, onSnapshot, query, type DocumentData } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import {
  clinicClientLinkFromFirestore,
  clinicFromFirestore,
  clinicMemberFromFirestore,
  userProfileFromFirestore,
  type Clinic,
  type ClinicClientLink,
  type ClinicMember,
  type UserProfile,
} from '@vetplus/shared';
import { db, functions } from './firebase';
import { useCollection, useDoc } from './useFirestore';
import { clientLabel } from './clientService';

export const clinicsCol = () => collection(db, 'clinics');
export const clinicDoc = (id: string) => doc(db, 'clinics', id);
export const clinicMembersCol = (clinicId: string) =>
  collection(db, 'clinics', clinicId, 'members');
export const clinicClientsCol = (clinicId: string) =>
  collection(db, 'clinics', clinicId, 'clients');

const mapClinic = (id: string, d: DocumentData): Clinic => clinicFromFirestore(id, d);
const mapMember = (id: string, d: DocumentData): ClinicMember & { uid: string } => ({
  ...clinicMemberFromFirestore(d),
  uid: id,
});
const mapLink = (id: string, d: DocumentData): ClinicClientLink & { id: string } => ({
  ...clinicClientLinkFromFirestore(d),
  id,
});

/** The active clinic document, live. */
export function useClinic(clinicId: string): { clinic: Clinic | null; loading: boolean } {
  const ref = useMemo(() => (clinicId ? clinicDoc(clinicId) : null), [clinicId]);
  const { data, loading } = useDoc<Clinic>(ref, mapClinic);
  return { clinic: clinicId ? data : null, loading: clinicId ? loading : false };
}

/** The clinic's staff roster, live, sorted by name. */
export function useClinicMembers(clinicId: string): {
  members: (ClinicMember & { uid: string })[];
  loading: boolean;
} {
  const q = useMemo(() => (clinicId ? query(clinicMembersCol(clinicId)) : null), [clinicId]);
  const { data, loading } = useCollection(q, mapMember);
  const members = useMemo(
    () => [...data].sort((a, b) => a.displayName.localeCompare(b.displayName)),
    [data],
  );
  return { members: clinicId ? members : [], loading: clinicId ? loading : false };
}

/**
 * One-shot load of several clinic docs (picker / switcher / note labels).
 * Gets are allowed for members and linked clients; failures are dropped.
 */
export function useClinicsByIds(ids: string[]): { clinics: Clinic[]; loading: boolean } {
  const [clinics, setClinics] = useState<Clinic[]>([]);
  const [loading, setLoading] = useState(false);
  const key = ids.join(',');
  useEffect(() => {
    if (ids.length === 0) {
      setClinics([]);
      return;
    }
    let active = true;
    setLoading(true);
    void Promise.all(
      ids.map((id) =>
        getDoc(clinicDoc(id))
          .then((s) => (s.exists() ? clinicFromFirestore(id, s.data()) : null))
          .catch(() => null),
      ),
    ).then((found) => {
      if (active) {
        setClinics(found.filter((c): c is Clinic => c !== null));
        setLoading(false);
      }
    });
    return () => {
      active = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);
  return { clinics, loading };
}

/**
 * The clinic's linked clients (active links) + pending link requests.
 * Listens to clinics/{c}/clients for the links and to each linked client's
 * users/{id} doc for the profile.
 */
export function useClinicClients(clinicId: string): {
  clients: UserProfile[];
  pending: (ClinicClientLink & { id: string })[];
  loading: boolean;
  error: unknown;
} {
  const q = useMemo(() => (clinicId ? query(clinicClientsCol(clinicId)) : null), [clinicId]);
  const { data: links, loading, error } = useCollection(q, mapLink);

  const pending = useMemo(() => links.filter((l) => l.status === 'pending'), [links]);
  const activeIds = useMemo(
    () =>
      links
        .filter((l) => l.status === 'active')
        .map((l) => l.clientId)
        .sort(),
    [links],
  );

  const [clients, setClients] = useState<UserProfile[]>([]);
  const [profilesLoading, setProfilesLoading] = useState(false);
  const idsKey = activeIds.join(',');
  useEffect(() => {
    if (activeIds.length === 0) {
      setClients([]);
      setProfilesLoading(false);
      return;
    }
    setProfilesLoading(true);
    const byId = new Map<string, UserProfile>();
    const answered = new Set<string>();
    const settle = (id: string) => {
      answered.add(id);
      if (answered.size === activeIds.length) setProfilesLoading(false);
    };
    const unsubs = activeIds.map((id) =>
      onSnapshot(
        doc(db, 'users', id),
        (snap) => {
          if (snap.exists()) byId.set(id, userProfileFromFirestore(id, snap.data()));
          else byId.delete(id);
          setClients(
            [...byId.values()].sort((a, b) => clientLabel(a).localeCompare(clientLabel(b))),
          );
          settle(id);
        },
        () => settle(id),
      ),
    );
    return () => unsubs.forEach((u) => u());
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [idsKey]);

  return {
    clients: clinicId ? clients : [],
    pending: clinicId ? pending : [],
    loading: clinicId ? loading || profilesLoading : false,
    error,
  };
}

/** Staff adds a client to the clinic (callable). */
export async function addClinicClient(args: {
  clinicId: string;
  name: string;
  email?: string;
}): Promise<{ clientId: string; status: 'pending' | 'active'; created: boolean }> {
  const call = httpsCallable<
    { clinicId: string; name: string; email?: string },
    { clientId: string; status: 'pending' | 'active'; created: boolean }
  >(functions, 'addClinicClient');
  const email = args.email?.trim().toLowerCase();
  const res = await call({ clinicId: args.clinicId, name: args.name.trim(), email: email || undefined });
  return res.data;
}
