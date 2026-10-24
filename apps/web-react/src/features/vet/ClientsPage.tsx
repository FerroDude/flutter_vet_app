import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { toast } from 'sonner';
import { ChevronRight, Mail, Phone, Plus, Search, Users } from 'lucide-react';
import { useAuth } from '@/auth/AuthProvider';
import { useClients } from '@/lib/useClients';
import { addClientByEmail, clientLabel } from '@/lib/clientService';
import { errorMessage } from '@/lib/format';
import { PageHeader } from '@/components/ui/PageHeader';
import { Card } from '@/components/ui/Card';
import { EmptyState } from '@/components/ui/EmptyState';
import { Button } from '@/components/ui/Button';
import { Dialog } from '@/components/ui/Dialog';
import { TextField } from '@/components/ui/TextField';
import { t } from '@/i18n';

export function ClientsPage() {
  const { firebaseUser, profile } = useAuth();
  const navigate = useNavigate();
  const uid = firebaseUser?.uid ?? '';
  const { clients, error } = useClients(uid);

  const [search, setSearch] = useState('');
  const [addOpen, setAddOpen] = useState(false);
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [adding, setAdding] = useState(false);

  const shown = useMemo(() => {
    const s = search.trim().toLowerCase();
    return s
      ? clients.filter((c) => clientLabel(c).toLowerCase().includes(s) || c.email.toLowerCase().includes(s))
      : clients;
  }, [clients, search]);

  const addClient = async () => {
    setAdding(true);
    try {
      await addClientByEmail({ vetId: uid, vetName: profile?.displayName?.trim() || t('common.vet'), name, email });
      toast.success(t('vet.clients.added'));
      setName('');
      setEmail('');
      setAddOpen(false);
    } catch (e) {
      toast.error(errorMessage(e, t('vet.clients.addFailed')));
    } finally {
      setAdding(false);
    }
  };

  return (
    <div>
      <PageHeader
        eyebrow={t('vet.clients.eyebrow')}
        title={t('vet.clients')}
        subtitle={t('vet.clients.subtitle')}
        actions={
          <Button onClick={() => setAddOpen(true)}>
            <Plus size={16} /> {t('vet.clients.add')}
          </Button>
        }
      />

      {clients.length > 0 && (
        <div className="relative mb-5 max-w-sm">
          <Search
            size={16}
            className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground"
          />
          <input
            type="search"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder={t('vet.clients.search')}
            aria-label={t('vet.clients.searchAria')}
            className="h-11 w-full rounded-(--radius-md) border border-input bg-card pl-9 pr-3 text-sm text-foreground focus-visible:border-ring focus-visible:outline-1 focus-visible:outline-offset-0 focus-visible:outline-ring"
          />
        </div>
      )}

      {error ? (
        <EmptyState icon={<Users size={36} />} title={t('vet.clients.loadFailed')} description={t('vet.clients.tryAgain')} />
      ) : shown.length === 0 ? (
        <EmptyState
          icon={<Users size={36} />}
          title={search ? t('vet.clients.noResults') : t('vet.clients.empty')}
          description={
            search ? t('vet.clients.tryOther') : t('vet.clients.emptyHint')
          }
        />
      ) : (
        <div className="space-y-3">
          {shown.map((c) => (
            <Card key={c.id}>
              <button
                type="button"
                onClick={() => navigate(`/clients/${c.id}`)}
                className="flex w-full items-center gap-4 p-5 text-left"
              >
                <span className="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-primary-light text-base font-semibold text-primary">
                  {clientLabel(c).charAt(0).toUpperCase()}
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate font-medium text-foreground">{clientLabel(c)}</span>
                  <span className="flex flex-wrap items-center gap-x-4 gap-y-0.5 text-xs text-muted-foreground">
                    <span className="inline-flex min-w-0 max-w-full items-center gap-1">
                      <Mail size={12} className="shrink-0" />
                      <span className="truncate">{c.email}</span>
                    </span>
                    {c.phone && (
                      <span className="inline-flex items-center gap-1">
                        <Phone size={12} /> {c.phone}
                      </span>
                    )}
                  </span>
                </span>
                <ChevronRight size={18} className="shrink-0 text-muted-foreground" />
              </button>
            </Card>
          ))}
        </div>
      )}

      <Dialog
        open={addOpen}
        onClose={() => (adding ? undefined : setAddOpen(false))}
        title={t('vet.clients.add')}
        description={t('vet.clients.addDesc')}
        footer={
          <>
            <Button variant="outline" disabled={adding} onClick={() => setAddOpen(false)}>
              {t('common.cancel')}
            </Button>
            <Button loading={adding} onClick={() => void addClient()}>
              {t('vet.clients.invite')}
            </Button>
          </>
        }
      >
        <form
          className="space-y-3"
          onSubmit={(e) => {
            e.preventDefault();
            void addClient();
          }}
        >
          <TextField label={t('common.name')} value={name} onChange={(e) => setName(e.target.value)} />
          <TextField label={t('common.email')} type="email" value={email} onChange={(e) => setEmail(e.target.value)} />
          <button type="submit" hidden />
        </form>
      </Dialog>
    </div>
  );
}
