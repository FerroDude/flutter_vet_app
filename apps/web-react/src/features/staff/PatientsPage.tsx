import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { toast } from 'sonner';
import { Search, Users, ChevronRight, Mail, Phone, Building2, Plus } from 'lucide-react';
import { type UserProfile } from '@vetplus/shared';
import { useAuth } from '@/auth/AuthProvider';
import { useCollection } from '@/lib/useFirestore';
import { clinicPatientsQuery, mapPatient, isPatient } from '@/lib/clinicService';
import { addClientByEmail, clientsQuery } from '@/lib/clientService';
import { PageHeader } from '@/components/ui/PageHeader';
import { Card, CardBody } from '@/components/ui/Card';
import { EmptyState } from '@/components/ui/EmptyState';
import { Button } from '@/components/ui/Button';
import { Dialog } from '@/components/ui/Dialog';
import { TextField } from '@/components/ui/TextField';

export function PatientsPage() {
  const { connectedClinic, firebaseUser, profile, role } = useAuth();
  const navigate = useNavigate();
  const clinicId = connectedClinic?.id ?? '';
  const uid = firebaseUser?.uid ?? '';
  const isVet = role === 'vet';

  const q = useMemo(() => {
    if (isVet && uid) return clientsQuery(uid);
    return clinicId ? clinicPatientsQuery(clinicId) : null;
  }, [isVet, uid, clinicId]);
  const { data: raw, error } = useCollection<UserProfile>(q, mapPatient);

  const [search, setSearch] = useState('');
  const [addOpen, setAddOpen] = useState(false);
  const [clientName, setClientName] = useState('');
  const [clientEmail, setClientEmail] = useState('');
  const [adding, setAdding] = useState(false);
  const patients = useMemo(() => {
    const list = raw.filter(isPatient);
    const s = search.trim().toLowerCase();
    const filtered = s
      ? list.filter(
          (p) =>
            (p.displayName ?? '').toLowerCase().includes(s) ||
            (p.email ?? '').toLowerCase().includes(s),
        )
      : list;
    return filtered.sort((a, b) =>
      (a.displayName || a.email || '').localeCompare(b.displayName || b.email || ''),
    );
  }, [raw, search]);

  const addClient = async () => {
    setAdding(true);
    try {
      await addClientByEmail({
        vetId: uid,
        vetName: profile?.displayName?.trim() || profile?.email || 'Vet',
        name: clientName,
        email: clientEmail,
      });
      toast.success('Cliente adicionado. Vai receber um email para definir a palavra-passe.');
      setClientName('');
      setClientEmail('');
      setAddOpen(false);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Não foi possível adicionar o cliente');
    } finally {
      setAdding(false);
    }
  };

  if (!isVet && !connectedClinic) {
    return (
      <div>
        <PageHeader title="Clientes" />
        <EmptyState
          icon={<Building2 size={36} />}
          title="Sem clínica"
          description="Esta conta ainda não está ligada a uma clínica."
        />
      </div>
    );
  }

  return (
    <div>
      <PageHeader
        eyebrow={isVet ? 'Prática' : 'Clínica'}
        title="Clientes"
        subtitle={isVet ? 'As pessoas de quem trata.' : `Tutores em ${connectedClinic?.name ?? 'a clínica'}.`}
        actions={
          isVet ? (
            <Button onClick={() => setAddOpen(true)}>
              <Plus size={16} /> Adicionar cliente
            </Button>
          ) : undefined
        }
      />

      <div className="relative mb-5">
        <Search
          size={16}
          className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground"
        />
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Procurar por nome ou email…"
          className="h-11 w-full rounded-(--radius-md) border border-input bg-card pl-9 pr-3 text-sm text-foreground focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring"
        />
      </div>

      {error ? (
        <EmptyState
          icon={<Users size={36} />}
          title="Não foi possível carregar os clientes"
          description={
            /permission/i.test(error.message)
              ? 'A lista está bloqueada até as regras novas serem publicadas.'
              : 'A lista não carregou. Tente outra vez.'
          }
        />
      ) : patients.length === 0 ? (
        <EmptyState
          icon={<Users size={36} />}
          title={search ? 'Sem resultados' : 'Ainda sem clientes'}
          description={
            search
              ? 'Tente outro nome ou email.'
              : isVet
                ? 'Adicione um cliente. Recebe um email para definir a palavra-passe.'
                : 'Os tutores ligados à clínica aparecem aqui.'
          }
        />
      ) : (
        <div className="space-y-3">
          {patients.map((p) => (
            <Card key={p.id}>
              <CardBody>
                <button
                  type="button"
                  onClick={() => navigate(`/patients/${p.id}`)}
                  className="flex w-full items-center gap-4 text-left"
                >
                  <span className="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-primary-light text-base font-semibold text-primary">
                    {(p.displayName || p.email || '?').charAt(0).toUpperCase()}
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate font-medium text-foreground">
                      {p.displayName || 'Sem nome'}
                    </span>
                    <span className="flex flex-wrap items-center gap-x-4 gap-y-0.5 text-xs text-muted-foreground">
                      {p.email && (
                        <span className="inline-flex items-center gap-1">
                          <Mail size={12} /> {p.email}
                        </span>
                      )}
                      {p.phone && (
                        <span className="inline-flex items-center gap-1">
                          <Phone size={12} /> {p.phone}
                        </span>
                      )}
                    </span>
                  </span>
                  <ChevronRight size={18} className="shrink-0 text-muted-foreground" />
                </button>
              </CardBody>
            </Card>
          ))}
        </div>
      )}

      <Dialog
        open={addOpen}
        onClose={() => (adding ? undefined : setAddOpen(false))}
        title="Adicionar cliente"
        description="Recebe um email para definir a palavra-passe. Depois pode enviar mensagens e pedir marcações."
        footer={
          <>
            <Button variant="outline" disabled={adding} onClick={() => setAddOpen(false)}>
              Cancelar
            </Button>
            <Button loading={adding} onClick={() => void addClient()}>
              Enviar convite
            </Button>
          </>
        }
      >
        <div className="space-y-3">
          <TextField label="Nome" value={clientName} onChange={(e) => setClientName(e.target.value)} />
          <TextField
            label="Email"
            type="email"
            value={clientEmail}
            onChange={(e) => setClientEmail(e.target.value)}
          />
        </div>
      </Dialog>
    </div>
  );
}
