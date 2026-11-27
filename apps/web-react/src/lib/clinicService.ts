// Clinics (VetTempo): the clinic doc, its staff roster and the client links.
// clinics/{clinicId}         — name, brand, contact (get-only for members/clients)
// clinics/{clinicId}/members — staff roster (server-written)
// clinics/{clinicId}/clients — client links: pending | active | declined (server-written)

import { useEffect, useMemo, useState } from 'react';
import {
  collection,
  collectionGroup,
  doc,
  getDoc,
  onSnapshot,
  query,
  updateDoc,
  where,
  type DocumentData,
} from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { sendPasswordResetEmail } from 'firebase/auth';
import { deleteObject, getDownloadURL, ref, uploadBytes } from 'firebase/storage';
import {
  clinicClientLinkFromFirestore,
  clinicFromFirestore,
  clinicMemberFromFirestore,
  userProfileFromFirestore,
  type Clinic,
  type ClinicBrand,
  type ClinicClientLink,
  type ClinicContact,
  type ClinicMember,
  type ClinicMemberRole,
  type UserProfile,
} from '@vetplus/shared';
import { auth, db, functions, storage } from './firebase';
import { appLoginUrl } from './authLinks';
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

/* ---------------------------- owner: settings ----------------------------- */

/** Owner adds a staff member (vet or owner) to the clinic (callable). */
export async function createClinicVet(args: {
  clinicId: string;
  name: string;
  email: string;
  role: ClinicMemberRole;
}): Promise<{ uid: string; created: boolean }> {
  const call = httpsCallable<
    { clinicId: string; name: string; email: string; role: ClinicMemberRole },
    { uid: string; created: boolean }
  >(functions, 'createClinicVet');
  const res = await call({
    clinicId: args.clinicId,
    name: args.name.trim(),
    email: args.email.trim().toLowerCase(),
    role: args.role,
  });
  return res.data;
}

/** Owner changes a member's role or active flag (callable). */
export async function updateClinicMember(args: {
  clinicId: string;
  uid: string;
  role?: ClinicMemberRole;
  active?: boolean;
}): Promise<void> {
  const call = httpsCallable<
    { clinicId: string; uid: string; role?: ClinicMemberRole; active?: boolean },
    { ok: true }
  >(functions, 'updateClinicMember');
  await call(args);
}

/** Sends the set-password email to a new staff account (same as client invites). */
export async function sendStaffInvite(email: string): Promise<void> {
  await sendPasswordResetEmail(auth, email, { url: appLoginUrl(email) });
}

/** Owner saves the clinic brand (rules: onlyChanges name/brand/contact/updatedAt). */
export async function updateClinicBrand(clinicId: string, brand: ClinicBrand): Promise<void> {
  await updateDoc(clinicDoc(clinicId), {
    brand: {
      primary: brand.primary,
      accent: brand.accent ?? null,
      logoWideUrl: brand.logoWideUrl ?? null,
      logoMarkUrl: brand.logoMarkUrl ?? null,
    },
    updatedAt: Date.now(),
  });
}

/** Owner saves the clinic name + public contact block. */
export async function updateClinicDetails(
  clinicId: string,
  args: { name: string; contact: ClinicContact },
): Promise<void> {
  await updateDoc(clinicDoc(clinicId), {
    name: args.name.trim(),
    contact: {
      phone: args.contact.phone?.trim() || null,
      address: args.contact.address?.trim() || null,
      postalCode: args.contact.postalCode?.trim() || null,
    },
    updatedAt: Date.now(),
  });
}

export type ClinicLogoKind = 'wide' | 'mark';

/** Uploads a clinic logo to clinics/{id}/branding/; returns the download URL. */
export async function uploadClinicLogo(
  clinicId: string,
  kind: ClinicLogoKind,
  file: File,
): Promise<string> {
  const ext = file.name.includes('.') ? file.name.split('.').pop()!.toLowerCase() : 'png';
  const path = `clinics/${clinicId}/branding/logo-${kind}-${Date.now()}.${ext}`;
  const r = ref(storage, path);
  await uploadBytes(r, file, { contentType: file.type || undefined });
  return getDownloadURL(r);
}

/**
 * Best-effort delete of the previous logo file — only when its download URL
 * points into this clinic's branding folder. Errors are ignored on purpose.
 */
export async function deleteClinicLogoFile(clinicId: string, url: string | null): Promise<void> {
  if (!url || !url.includes(`clinics%2F${clinicId}%2Fbranding`)) return;
  try {
    await deleteObject(ref(storage, url));
  } catch {
    /* already gone / foreign */
  }
}

/* ------------------------- client: my clinic links ------------------------ */

/**
 * The signed-in client's links across ALL clinics (collection group).
 * `pending` = invites awaiting the client's answer; `active` = accepted.
 */
export function useMyClinicLinks(uid: string): {
  pending: (ClinicClientLink & { clinicId: string })[];
  active: (ClinicClientLink & { clinicId: string })[];
  loading: boolean;
} {
  const [state, setState] = useState<{
    pending: (ClinicClientLink & { clinicId: string })[];
    active: (ClinicClientLink & { clinicId: string })[];
    loading: boolean;
  }>({ pending: [], active: [], loading: true });

  useEffect(() => {
    if (!uid) {
      setState({ pending: [], active: [], loading: false });
      return;
    }
    return onSnapshot(
      query(collectionGroup(db, 'clients'), where('clientId', '==', uid)),
      (snap) => {
        const all = snap.docs.map((d) => ({
          ...clinicClientLinkFromFirestore(d.data() as DocumentData),
          clinicId: d.ref.parent.parent?.id ?? '',
        }));
        setState({
          pending: all.filter((l) => l.status === 'pending'),
          active: all.filter((l) => l.status === 'active'),
          loading: false,
        });
      },
      () => setState({ pending: [], active: [], loading: false }),
    );
  }, [uid]);

  return state;
}

/** Client answers a clinic link request (callable). */
export async function respondClinicLink(args: {
  clinicId: string;
  accept: boolean;
}): Promise<'active' | 'declined'> {
  const call = httpsCallable<
    { clinicId: string; accept: boolean },
    { status: 'active' | 'declined' }
  >(functions, 'respondClinicLink');
  return (await call(args)).data.status;
}

/** Client leaves a clinic they belong to (callable). */
export async function leaveClinic(clinicId: string): Promise<{
  closedRooms: number;
  cancelledRequests: number;
  cancelledAppointments: number;
}> {
  const call = httpsCallable<
    { clinicId: string },
    { ok: true; closedRooms: number; cancelledRequests: number; cancelledAppointments: number }
  >(functions, 'leaveClinic');
  return (await call({ clinicId })).data;
}
