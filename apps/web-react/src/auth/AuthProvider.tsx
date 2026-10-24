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
import { type UserProfile, isVet, isPetOwner } from '@vetplus/shared';
import { auth } from '@/lib/firebase';
import { getUserProfile, updateUserProfile } from '@/lib/userService';

export type Role = 'vet' | 'petOwner' | 'unknown';

interface ProfileUpdate {
  displayName?: string;
  phone?: string | null;
  address?: string | null;
  postalCode?: string | null;
}

interface AuthState {
  firebaseUser: User | null;
  profile: UserProfile | null;
  role: Role;
  loading: boolean;
  profileLoading: boolean;
  error: string | null;
  refreshProfile: () => Promise<void>;
  signOutUser: () => Promise<void>;
  updateProfile: (fields: ProfileUpdate) => Promise<void>;
}

const AuthContext = createContext<AuthState | undefined>(undefined);

function resolveRole(profile: UserProfile | null): Role {
  if (!profile) return 'unknown';
  if (isVet(profile)) return 'vet';
  if (isPetOwner(profile)) return 'petOwner';
  return 'unknown';
}

/**
 * Accounts are never created here: vets come from scripts/create-vet.mjs and
 * clients are added by their vet. A signed-in user without a profile has no
 * access. No email-verification gate: nobody can sign up, and clients set
 * their password from the email the vet's invite sends.
 */
export function AuthProvider({ children }: { children: ReactNode }) {
  const [firebaseUser, setFirebaseUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [profileLoading, setProfileLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Prevent overlapping/duplicate profile loads (e.g. StrictMode double-invoke).
  const loadSeq = useRef(0);

  const loadProfileFor = useCallback(async (user: User) => {
    const seq = ++loadSeq.current;
    setProfileLoading(true);
    setError(null);
    try {
      const found = await getUserProfile(user.uid);
      if (seq !== loadSeq.current) return; // superseded by a newer load
      setProfile(found);
      if (!found) setError('Esta conta não tem acesso. Peça à sua veterinária para a adicionar.');
    } catch (e) {
      if (seq === loadSeq.current) {
        setError(e instanceof Error ? e.message : 'Não foi possível carregar o perfil');
        setProfile(null);
      }
    } finally {
      if (seq === loadSeq.current) setProfileLoading(false);
    }
  }, []);

  useEffect(
    () =>
      onAuthStateChanged(auth, (user) => {
        setFirebaseUser(user);
        const done = user ? loadProfileFor(user) : Promise.resolve();
        if (!user) {
          loadSeq.current++; // cancel any in-flight load
          setProfile(null);
          setError(null);
        }
        void done.finally(() => setLoading(false));
      }),
    [loadProfileFor],
  );

  const refreshProfile = useCallback(async () => {
    if (auth.currentUser) await loadProfileFor(auth.currentUser);
  }, [loadProfileFor]);

  const signOutUser = useCallback(async () => {
    await signOut(auth);
  }, []);

  const updateProfile = useCallback(
    async (fields: ProfileUpdate) => {
      if (!profile) return;
      const updated: UserProfile = {
        ...profile,
        displayName: fields.displayName ?? profile.displayName,
        phone: fields.phone !== undefined ? fields.phone : profile.phone,
        address: fields.address !== undefined ? fields.address : profile.address,
        postalCode: fields.postalCode !== undefined ? fields.postalCode : profile.postalCode,
        updatedAt: new Date(),
      };
      await updateUserProfile(updated);
      setProfile(updated);
    },
    [profile],
  );

  const value = useMemo<AuthState>(
    () => ({
      firebaseUser,
      profile,
      role: resolveRole(profile),
      loading,
      profileLoading,
      error,
      refreshProfile,
      signOutUser,
      updateProfile,
    }),
    [firebaseUser, profile, loading, profileLoading, error, refreshProfile, signOutUser, updateProfile],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within <AuthProvider>');
  return ctx;
}

/** A vet must set a display name before using the app (clients see it). */
export function needsDisplayName(profile: UserProfile | null): boolean {
  return Boolean(profile && isVet(profile) && !profile.displayName.trim());
}
