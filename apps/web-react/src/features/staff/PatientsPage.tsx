import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Search, Users, ChevronRight, Mail, Phone, Building2 } from 'lucide-react';
import { type UserProfile } from '@vetplus/shared';
import { useAuth } from '@/auth/AuthProvider';
import { useCollection } from '@/lib/useFirestore';
import { clinicPatientsQuery, mapPatient, isPatient } from '@/lib/clinicService';
import { PageHeader } from '@/components/ui/PageHeader';
import { Card, CardBody } from '@/components/ui/Card';
import { EmptyState } from '@/components/ui/EmptyState';

export function PatientsPage() {
  const { connectedClinic } = useAuth();
  const navigate = useNavigate();
  const clinicId = connectedClinic?.id ?? '';

  const q = useMemo(() => (clinicId ? clinicPatientsQuery(clinicId) : null), [clinicId]);
  const { data: raw, error } = useCollection<UserProfile>(q, mapPatient);

  const [search, setSearch] = useState('');
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

  if (!connectedClinic) {
    return (
      <div>
        <PageHeader title="Patients" />
        <EmptyState
          icon={<Building2 size={36} />}
          title="No clinic"
          description="Your account isn't linked to a clinic yet."
        />
      </div>
    );
  }

  return (
    <div>
      <PageHeader eyebrow="Clinic" title="Patients" subtitle={`Pet owners at ${connectedClinic.name}.`} />

      <div className="relative mb-5">
        <Search
          size={16}
          className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground"
        />
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search by name or email…"
          className="h-11 w-full rounded-(--radius-md) border border-input bg-card pl-9 pr-3 text-sm text-foreground focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring"
        />
      </div>

      {error ? (
        <EmptyState
          icon={<Users size={36} />}
          title="Couldn't load patients"
          description={
            'There was a problem loading patients. This usually means your staff account ' +
            "isn't fully linked to the clinic yet. Try signing out and back in. " +
            `(${error.message})`
          }
        />
      ) : patients.length === 0 ? (
        <EmptyState
          icon={<Users size={36} />}
          title={search ? 'No matches' : 'No patients yet'}
          description={
            search
              ? 'Try a different name or email.'
              : 'Pet owners who connect to your clinic will appear here.'
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
                      {p.displayName || 'Unnamed'}
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
    </div>
  );
}
