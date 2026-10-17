import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import type { Clinic } from '@vetplus/shared';
import { useAuth } from '@/auth/AuthProvider';
import * as svc from '@/lib/userService';
import { AuthShell } from '@/components/ui/AuthShell';
import { Button } from '@/components/ui/Button';
import { TextField } from '@/components/ui/TextField';
import { Spinner } from '@/components/Spinner';

export function ClinicSelectionScreen() {
  const { t } = useTranslation();
  const { connectToClinic, skipClinicSelection } = useAuth();
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<Clinic[] | null>(null);
  const [searching, setSearching] = useState(false);
  const [connectingId, setConnectingId] = useState<string | null>(null);
  const [skipping, setSkipping] = useState(false);

  async function search() {
    setSearching(true);
    try {
      setResults(await svc.searchClinics(query));
    } catch {
      toast.error(t('errors.generic'));
    } finally {
      setSearching(false);
    }
  }

  async function connect(clinic: Clinic) {
    setConnectingId(clinic.id);
    try {
      await connectToClinic(clinic.id);
      toast.success(t('clinic.connected'));
    } catch {
      toast.error(t('errors.generic'));
      setConnectingId(null);
    }
  }

  async function skip() {
    setSkipping(true);
    try {
      await skipClinicSelection();
    } catch {
      toast.error(t('errors.generic'));
      setSkipping(false);
    }
  }

  return (
    <AuthShell
      title={t('clinic.selectTitle')}
      subtitle={t('clinic.selectSubtitle')}
      footer={
        <Button variant="ghost" onClick={skip} loading={skipping}>
          {t('clinic.skip')}
        </Button>
      }
    >
      <form
        className="flex flex-col gap-3"
        onSubmit={(e) => {
          e.preventDefault();
          void search();
        }}
      >
        <TextField
          label={t('clinic.search')}
          placeholder={t('clinic.searchPlaceholder')}
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          autoFocus
        />
        <Button type="submit" fullWidth loading={searching}>
          {t('clinic.search')}
        </Button>
      </form>

      <div className="mt-5 flex flex-col gap-2">
        {searching && (
          <div className="flex justify-center py-4 text-primary">
            <Spinner size={24} />
          </div>
        )}
        {!searching && results?.length === 0 && (
          <p className="py-4 text-center text-sm text-muted-foreground">
            {t('clinic.noResults')}
          </p>
        )}
        {!searching &&
          results?.map((clinic) => (
            <div
              key={clinic.id}
              className="flex items-center justify-between gap-3 rounded-(--radius-md) border border-border bg-card px-4 py-3"
            >
              <div className="min-w-0">
                <p className="truncate font-medium text-foreground">{clinic.name}</p>
                <p className="truncate text-xs text-muted-foreground">{clinic.address}</p>
              </div>
              <Button
                size="md"
                loading={connectingId === clinic.id}
                onClick={() => connect(clinic)}
              >
                {t('clinic.connect')}
              </Button>
            </div>
          ))}
      </div>
    </AuthShell>
  );
}
