import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import { onAuthStateChanged, signOut, type User } from 'firebase/auth';
import {
  type UserProfile,
  type Clinic,
  ClinicRole,
  UserType,
  isAppOwner,
  isClinicAdmin,
  isVet,
  isReceptionist,
  isPetOwner,
} from '@vetplus/shared';
import { auth } from '@/lib/firebase';
import * as svc from '@/lib/userService';
import { resolveUserProfile } from './linking';

export type Role =
  | 'appOwner'
  | 'clinicAdmin'
  | 'vet'
  | 'receptionist'
  | 'petOwner'
  | 'unknown';

interface ProfileUpdate {
  displayName?: string;
  email?: string;
  phone?: string | null;
  address?: string | null;
  hasSkippedClinicSelection?: boolean;
}

interface AuthState {
  firebaseUser: User | null;
  profile: UserProfile | null;
  connectedClinic: Clinic | null;
  role: Role;
  loading: boolean;
  profileLoading: boolean;
  error: string | null;
  emailVerified: boolean;
  refreshProfile: () => Promise<void>;
  reloadFirebaseUser: () => Promise<void>;
  signOutUser: () => Promise<void>;
  updateProfile: (fields: ProfileUpdate) => Promise<void>;
  skipClinicSelection: () => Promise<void>;
  connectToClinic: (clinicId: string) => Promise<void>;
  disconnectFromClinic: () => Promise<void>;
  deleteAccount: () => Promise<void>;
  clearError: () => void;
}

const AuthContext = createContext<AuthState | undefined>(undefined);

function resolveRole(profile: UserProfile | null): Role {
  if (!profile) return 'unknown';
  if (isAppOwner(profile)) return 'appOwner';
  if (isClinicAdmin(profile)) return 'clinicAdmin';
  if (isVet(profile)) return 'vet';
  if (isReceptionist(profile)) return 'receptionist';
  if (isPetOwner(profile)) return 'petOwner';
  return 'unknown';
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [firebaseUser, setFirebaseUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [connectedClinic, setConnectedClinic] = useState<Clinic | null>(null);
  const [loading, setLoading] = useState(true);
  const [profileLoading, setProfileLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Prevent overlapping/duplicate profile loads (e.g. StrictMode double-invoke).
  const loadSeq = useRef(0);

  const loadConnectedClinic = useCallback(async (clinicId: string | null | undefined) => {
    if (!clinicId) {
      setConnectedClinic(null);
      return;
    }
    try {
      setConnectedClinic(await svc.getClinic(clinicId));
    } catch {
      setConnectedClinic(null);
    }
  }, []);

  const loadProfileFor = useCallback(
    async (user: User) => {
      const seq = ++loadSeq.current;
      setProfileLoading(true);
      setError(null);
      try {
        let resolved = await resolveUserProfile(user);

        // Clinic admins without a linked clinic: discover by ownership.
        if (resolved && isClinicAdmin(resolved) && !resolved.connectedClinicId) {
          const owned = await svc.findClinicByAdmin(resolved.id);
          if (owned) {
            resolved = {
              ...resolved,
              connectedClinicId: owned.id,
              clinicRole: ClinicRole.admin,
              updatedAt: new Date(),
            };
            await svc.updateUserProfile(resolved);
          }
        }

        if (seq !== loadSeq.current) return; // superseded by a newer load
        setProfile(resolved);
        await loadConnectedClinic(resolved?.connectedClinicId);
      } catch (e) {
        if (seq === loadSeq.current) {
          setError(e instanceof Error ? e.message : 'Failed to load profile');
          setProfile(null);
        }
      } finally {
        if (seq === loadSeq.current) setProfileLoading(false);
      }
    },
    [loadConnectedClinic],
  );

  const evaluateUser = useCallback(
    async (user: User | null) => {
      setFirebaseUser(user);
      if (user && user.emailVerified) {
        await loadProfileFor(user);
      } else {
        loadSeq.current++; // cancel any in-flight load
        setProfile(null);
        setConnectedClinic(null);
      }
      setLoading(false);
    },
    [loadProfileFor],
  );

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, (user) => {
      void evaluateUser(user);
    });
    return unsub;
  }, [evaluateUser]);

  const refreshProfile = useCallback(async () => {
    if (auth.currentUser) await loadProfileFor(auth.currentUser);
  }, [loadProfileFor]);

  const reloadFirebaseUser = useCallback(async () => {
    const user = auth.currentUser;
    if (!user) return;
    await user.reload();
    await user.getIdToken(true);
    await evaluateUser(auth.currentUser);
  }, [evaluateUser]);

  const signOutUser = useCallback(async () => {
    await signOut(auth);
  }, []);

  const updateProfile = useCallback(
    async (fields: ProfileUpdate) => {
      if (!profile) return;
      const updated: UserProfile = {
        ...profile,
        displayName: fields.displayName ?? profile.displayName,
        email: fields.email ?? profile.email,
        phone: fields.phone !== undefined ? fields.phone : profile.phone,
        address: fields.address !== undefined ? fields.address : profile.address,
        hasSkippedClinicSelection:
          fields.hasSkippedClinicSelection ?? profile.hasSkippedClinicSelection,
        updatedAt: new Date(),
      };
      await svc.updateUserProfile(updated);
      setProfile(updated);
    },
    [profile],
  );

  const skipClinicSelection = useCallback(async () => {
    if (!profile || !isPetOwner(profile)) return;
    await updateProfile({ hasSkippedClinicSelection: true });
  }, [profile, updateProfile]);

  const connectToClinic = useCallback(
    async (clinicId: string) => {
      if (!profile) return;
      await svc.connectUserToClinic(profile.id, clinicId);
      if (auth.currentUser) await loadProfileFor(auth.currentUser);
    },
    [profile, loadProfileFor],
  );

  const disconnectFromClinic = useCallback(async () => {
    if (!profile || !profile.connectedClinicId) return;
    await svc.disconnectUserFromClinic(profile.id);
    setConnectedClinic(null);
    if (auth.currentUser) await loadProfileFor(auth.currentUser);
  }, [profile, loadProfileFor]);

  const deleteAccount = useCallback(async () => {
    const user = auth.currentUser;
    if (!user) throw new Error('No user signed in');
    await svc.deleteUserProfileCascade(user.uid);
    await user.delete();
  }, []);

  const clearError = useCallback(() => setError(null), []);

  const value = useMemo<AuthState>(
    () => ({
      firebaseUser,
      profile,
      connectedClinic,
      role: resolveRole(profile),
      loading,
      profileLoading,
      error,
      emailVerified: Boolean(firebaseUser?.emailVerified),
      refreshProfile,
      reloadFirebaseUser,
      signOutUser,
      updateProfile,
      skipClinicSelection,
      connectToClinic,
      disconnectFromClinic,
      deleteAccount,
      clearError,
    }),
    [
      firebaseUser,
      profile,
      connectedClinic,
      loading,
      profileLoading,
      error,
      refreshProfile,
      reloadFirebaseUser,
      signOutUser,
      updateProfile,
      skipClinicSelection,
      connectToClinic,
      disconnectFromClinic,
      deleteAccount,
      clearError,
    ],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within <AuthProvider>');
  return ctx;
}

/** Helper to know if a staff member still needs to set a display name. */
export function needsDisplayName(profile: UserProfile | null): boolean {
  if (!profile) return false;
  const staff =
    profile.userType === UserType.vet ||
    profile.userType === UserType.receptionist ||
    isVet(profile) ||
    isReceptionist(profile);
  return staff && !profile.displayName.trim();
}
