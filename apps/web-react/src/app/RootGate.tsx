import { type ReactNode } from 'react';
import { useAuth, needsDisplayName } from '@/auth/AuthProvider';
import { PageSpinner } from '@/components/Spinner';
import { Button } from '@/components/ui/Button';
import { isFirebaseConfigured } from '@/lib/env';
import { AuthScreen } from '@/features/auth/AuthScreen';
import { DisplayNameScreen } from '@/features/auth/DisplayNameScreen';
import { ClientApp } from './ClientApp';
import { VetApp } from './VetApp';

/**
 * Top-level gate:
 *   not signed in       -> sign in
 *   loading / error     -> spinner / message
 *   vet without a name  -> name setup
 *   vet | client        -> their app
 */
export function RootGate() {
  const { loading, profileLoading, error, firebaseUser, profile, role, refreshProfile, signOutUser } =
    useAuth();

  if (!isFirebaseConfigured) {
    return (
      <Message title="Firebase não configurado">
        Copie .env.example para .env.local, preencha a config da app Web na consola Firebase e reinicie o
        servidor.
      </Message>
    );
  }

  if (loading) return <PageSpinner />;
  if (!firebaseUser) return <AuthScreen />;

  if (error || (!profileLoading && !profile) || (profile && role === 'unknown')) {
    return (
      <Message title="Sem acesso">
        {error ?? 'Esta conta não tem um papel definido. Contacte o suporte.'}
        <div className="mt-4 flex justify-center gap-2">
          <Button onClick={() => void refreshProfile()}>Tentar de novo</Button>
          <Button variant="outline" onClick={() => void signOutUser()}>
            Terminar sessão
          </Button>
        </div>
      </Message>
    );
  }

  if (profileLoading || !profile) return <PageSpinner />;
  if (needsDisplayName(profile)) return <DisplayNameScreen />;
  return role === 'vet' ? <VetApp /> : <ClientApp />;
}

function Message({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="mx-auto flex min-h-dvh max-w-md flex-col items-center justify-center px-6 text-center">
      <span className="text-[0.8125rem] font-semibold uppercase tracking-[0.06em] text-primary">Vet+</span>
      <h1 className="mt-2 font-display text-2xl font-bold text-foreground">{title}</h1>
      <div className="mt-2 text-sm text-muted-foreground">{children}</div>
    </div>
  );
}
