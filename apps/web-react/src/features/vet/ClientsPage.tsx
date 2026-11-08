import { useMemo, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { toast } from 'sonner';
import { ChevronRight, Mail, Phone, Plus, Search, Users } from 'lucide-react';
import { useAuth } from '@/auth/AuthProvider';
import { useClients } from '@/lib/useClients';
import { useClientPets } from '@/lib/useClientPets';
import { addClient as addClientToDb, clientLabel } from '@/lib/clientService';
import { errorMessage, normalizeText } from '@/lib/format';
import { PageHeader } from '@/components/ui/PageHeader';
import { Card } from '@/components/ui/Card';
import { EmptyState } from '@/components/ui/EmptyState';
import { Button } from '@/components/ui/Button';
import { Dialog } from '@/components/ui/Dialog';
import { TextField } from '@/components/ui/TextField';
import { PetAvatar } from '@/components/ui/PetAvatar';
import { Spinner } from '@/components/Spinner';
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
  const [sendInvite, setSendInvite] = useState(true);
  const [adding, setAdding] = useState(false);

  const q = normalizeText(search.trim());
  const { pets, loading: petsLoading } = useClientPets(clients, Boolean(q));

  const shown = useMemo(
    () =>
      q
        ? clients.filter(
            (c) => normalizeText(clientLabel(c)).includes(q) || normalizeText(c.email).includes(q),
          )
        : clients,
    [clients, q],
  );

  const shownPets = useMemo(
    () =>
      (q ? pets : [])
        .filter((p) => normalizeText(p.pet.name).includes(q))
        .sort(
          (a, b) =>
            a.pet.name.localeCompare(b.pet.name) ||
            clientLabel(a.owner).localeCompare(clientLabel(b.owner)),
        ),
    [pets, q],
  );

  const addClient = async () => {
    setAdding(true);
    try {
      const newUid = await addClientToDb({
        vetId: uid,
        vetName: profile?.displayName?.trim() || t('common.vet'),
        name,
        email,
        sendInvite,
      });
      const hasEmail = Boolean(email.trim());
      toast.success(
        t(hasEmail && sendInvite ? 'vet.clients.added' : 'vet.clients.addedNoInvite'),
      );
      setName('');
      setEmail('');
      setSendInvite(true);
      setAddOpen(false);
      if (!hasEmail || !sendInvite) navigate(`/clients/${newUid}`);
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
      ) : q && shown.length === 0 && shownPets.length === 0 && petsLoading ? (
        <div className="flex justify-center py-10">
          <Spinner />
        </div>
      ) : shown.length === 0 && (q ? shownPets.length === 0 : true) ? (
        <EmptyState
          icon={<Users size={36} />}
          title={search ? t('vet.clients.noResults') : t('vet.clients.empty')}
          description={
            search ? t('vet.clients.tryOther') : t('vet.clients.emptyHint')
          }
        />
      ) : (
        <div className="space-y-3">
          {shownPets.length > 0 && (
            <p className="text-[0.8125rem] font-semibold uppercase tracking-[0.08em] text-primary">
              {t('vet.clients.petsSection')}
            </p>
          )}
          {shownPets.map(({ pet, owner }) => (
            <Card key={`${owner.id}/${pet.id}`}>
              <div className="flex items-center gap-4 p-4">
                <Link
                  to={`/clients/${owner.id}/pets/${pet.id}`}
                  className="flex min-w-0 flex-1 items-center gap-3"
                >
                  <PetAvatar pet={pet} size={44} className="shrink-0" />
                  <span className="min-w-0">
                    <span className="block truncate font-medium text-foreground">{pet.name}</span>
                    <span className="block truncate text-xs text-muted-foreground">
                      {[pet.species, pet.breed].filter(Boolean).join(' · ') || t('pets.unknown')}
                    </span>
                  </span>
                </Link>
                <Link
                  to={`/clients/${owner.id}`}
                  className="max-w-[45%] truncate text-sm font-medium text-primary hover:underline"
                >
                  {t('vet.clients.owner', { name: clientLabel(owner) })}
                </Link>
              </div>
            </Card>
          ))}
          {q && shown.length > 0 && (
            <p className="pt-2 text-[0.8125rem] font-semibold uppercase tracking-[0.08em] text-primary">
              {t('vet.clients.clientsSection')}
            </p>
          )}
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
                  <span className="flex items-center gap-2">
                    <span className="truncate font-medium text-foreground">{clientLabel(c)}</span>
                    {(c.invitePending || !c.email) && (
                      <span className="shrink-0 rounded-full bg-secondary px-2 py-0.5 text-xs font-medium text-muted-foreground">
                        {c.email ? t('vet.clients.notInvited') : t('vet.clients.noEmail')}
                      </span>
                    )}
                  </span>
                  <span className="flex flex-wrap items-center gap-x-4 gap-y-0.5 text-xs text-muted-foreground">
                    {c.email && (
                      <span className="inline-flex min-w-0 max-w-full items-center gap-1">
                        <Mail size={12} className="shrink-0" />
                        <span className="truncate">{c.email}</span>
                      </span>
                    )}
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
              {email.trim() && sendInvite ? t('vet.clients.invite') : t('vet.clients.add')}
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
          <TextField label={t('vet.clients.emailOptional')} type="email" value={email} onChange={(e) => setEmail(e.target.value)} />
          <label
            className={`inline-flex items-center gap-2 text-sm ${email.trim() ? 'text-muted-foreground' : 'cursor-not-allowed text-muted-foreground/50'}`}
          >
            <input
              type="checkbox"
              checked={sendInvite && Boolean(email.trim())}
              disabled={!email.trim()}
              onChange={(e) => setSendInvite(e.target.checked)}
              className="h-4 w-4 accent-[hsl(var(--primary))]"
            />
            {t('vet.clients.sendInviteNow')}
          </label>
          {!email.trim() && (
            <p className="text-xs text-muted-foreground">{t('vet.clients.noEmailHint')}</p>
          )}
          <button type="submit" hidden />
        </form>
      </Dialog>
    </div>
  );
}
