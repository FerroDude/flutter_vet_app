// The active clinic for the signed-in user. Staff clinics come from
// profile.memberOf, client clinics from profile.clientOf. The choice is
// remembered per device in localStorage; >1 clinic shows a picker.

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import type { Clinic, ClinicMember } from '@vetplus/shared';
import { useAuth } from '@/auth/AuthProvider';
import { useBrand } from '@/lib/brand';
import { useClinic, useClinicMembers, useClinicsByIds } from '@/lib/clinicService';
import { ClinicLogo, VetTempoLogo } from '@/components/ui/Logo';
import { Button } from '@/components/ui/Button';
import { Card } from '@/components/ui/Card';
import { PageSpinner } from '@/components/Spinner';
import { t } from '@/i18n';


export interface ActiveClinic {
  /** '' when the user has no usable clinic (clients only — staff get gated). */
  clinicId: string;
  clinic: Clinic | null;
  /** All clinics the user belongs to (for the switcher). */
  clinics: Clinic[];
  members: (ClinicMember & { uid: string })[];
  myMember: (ClinicMember & { uid: string }) | null;
  isOwner: boolean;
  clinicIds: string[];
  setClinicId: (id: string) => void;
  /** Clinic id of a just-accepted link — anchors the "new clinic" hint. */
  newClinicHint: string | null;
  announceNewClinic: (id: string) => void;
  dismissClinicHint: () => void;
}

const Ctx = createContext<ActiveClinic | undefined>(undefined);
export { Ctx as ActiveClinicContext };

const KEY = 'vettempo-clinic';
const HINT_KEY = 'vettempo-clinic-hint';

function readStored(key: string): string | null {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

function writeStored(key: string, value: string | null) {
  try {
    if (value === null) localStorage.removeItem(key);
    else localStorage.setItem(key, value);
  } catch {
    /* ignore */
  }
}

export function useActiveClinic(): ActiveClinic {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error('useActiveClinic must be used within <ClinicProvider>');
  return ctx;
}

/**
 * Wraps the signed-in app. `kind` decides the no-clinic behaviour:
 * staff with zero clinics sees a blocking message; clients with zero clinics
 * just get clinicId '' and keep their pets/agenda.
 */
export function ClinicProvider({
  kind,
  clinicIds,
  children,
}: {
  kind: 'staff' | 'client';
  clinicIds: string[];
  children: ReactNode;
}) {
  const { firebaseUser, signOutUser } = useAuth();
  const uid = firebaseUser?.uid ?? '';
  const [chosen, setChosen] = useState<string | null>(() => readStored(KEY));
  const [hint, setHint] = useState<string | null>(() => readStored(HINT_KEY));

  const clinicId = useMemo(() => {
    if (chosen && clinicIds.includes(chosen)) return chosen;
    return clinicIds.length === 1 ? (clinicIds[0] ?? '') : '';
  }, [chosen, clinicIds]);

  const setClinicId = useCallback((id: string) => {
    setChosen(id);
    writeStored(KEY, id);
    // Switching clinics consumes the hint.
    setHint(null);
    writeStored(HINT_KEY, null);
  }, []);

  // Persist the resolved clinic so a growing clientOf/memberOf list doesn't
  // yank the user into the picker — an implicit single-clinic resolution is
  // still "their" clinic.
  useEffect(() => {
    if (clinicId && clinicId !== chosen) {
      setChosen(clinicId);
      writeStored(KEY, clinicId);
    }
  }, [clinicId, chosen]);

  const announceNewClinic = useCallback((id: string) => {
    setHint(id);
    writeStored(HINT_KEY, id);
  }, []);

  const dismissClinicHint = useCallback(() => {
    setHint(null);
    writeStored(HINT_KEY, null);
  }, []);

  const { clinic, loading: clinicLoading } = useClinic(clinicId);
  const { members, loading: membersLoading } = useClinicMembers(clinicId);
  const { clinics } = useClinicsByIds(clinicIds);
  useBrand(clinic?.brand ?? null);

  const myMember = useMemo(() => members.find((m) => m.uid === uid) ?? null, [members, uid]);

  const value = useMemo<ActiveClinic>(
    () => ({
      clinicId,
      clinic,
      clinics,
      members,
      myMember,
      isOwner: myMember?.role === 'owner' && myMember.active !== false,
      clinicIds,
      setClinicId,
      newClinicHint: hint,
      announceNewClinic,
      dismissClinicHint,
    }),
    [
      clinicId,
      clinic,
      clinics,
      members,
      myMember,
      clinicIds,
      setClinicId,
      hint,
      announceNewClinic,
      dismissClinicHint,
    ],
  );

  // Staff with no clinic at all gets a blocking message.
  if (kind === 'staff' && clinicIds.length === 0) {
    return (
      <GateMessage title={t('clinic.none.title')}>
        {t('clinic.none.body')}
        <div className="mt-4 flex justify-center">
          <Button variant="outline" onClick={() => void signOutUser()}>
            {t('common.signOut')}
          </Button>
        </div>
      </GateMessage>
    );
  }

  // >1 clinics and no valid remembered choice → picker first.
  const picking = clinicIds.length > 1 && !clinicId;
  if (picking) {
    return (
      <div className="mx-auto flex min-h-dvh max-w-md flex-col items-center justify-center px-6">
        <VetTempoLogo className="text-xl" />
        <h1 className="mt-4 font-display text-2xl font-bold text-foreground">
          {t('clinic.pick.title')}
        </h1>
        <p className="mt-1 text-center text-sm text-muted-foreground">{t('clinic.pick.body')}</p>
        <div className="mt-6 w-full space-y-2">
          {clinicIds.map((id) => {
            const c = clinics.find((x) => x.id === id);
            return (
              <Card key={id} className="w-full">
                <button
                  type="button"
                  onClick={() => setClinicId(id)}
                  className="flex w-full items-center gap-3 p-4 text-left"
                >
                  {c?.brand.logoWideUrl ? (
                    <ClinicLogo src={c.brand.logoWideUrl} name={c.name} className="h-6" />
                  ) : (
                    <span className="truncate font-semibold text-foreground">
                      {c?.name || id}
                    </span>
                  )}
                </button>
              </Card>
            );
          })}
        </div>
      </div>
    );
  }

  if (clinicId && (clinicLoading || membersLoading)) return <PageSpinner />;

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

function GateMessage({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="mx-auto flex min-h-dvh max-w-md flex-col items-center justify-center px-6 text-center">
      <VetTempoLogo className="text-xl" />
      <h1 className="mt-2 font-display text-2xl font-bold text-foreground">{title}</h1>
      <div className="mt-2 text-sm text-muted-foreground">{children}</div>
    </div>
  );
}
