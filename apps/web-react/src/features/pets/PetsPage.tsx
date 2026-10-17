import { useMemo, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { PawPrint, Plus, Search, Cake } from 'lucide-react';
import { useAuth } from '@/auth/AuthProvider';
import { petsQuery, mapPet, petAgeLabel, type Pet } from '@/lib/petService';
import { useCollection } from '@/lib/useFirestore';
import { PageHeader } from '@/components/ui/PageHeader';
import { EmptyState } from '@/components/ui/EmptyState';
import { Button } from '@/components/ui/Button';
import { Card } from '@/components/ui/Card';
import { PageSpinner } from '@/components/Spinner';

export function PetsPage() {
  const { firebaseUser } = useAuth();
  const navigate = useNavigate();
  const uid = firebaseUser?.uid ?? '';
  const query = useMemo(() => (uid ? petsQuery(uid) : null), [uid]);
  const { data: pets, loading } = useCollection<Pet>(query, mapPet);
  const [search, setSearch] = useState('');

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return pets;
    return pets.filter((p) =>
      [p.name, p.species, p.breed].some((f) => f.toLowerCase().includes(q)),
    );
  }, [pets, search]);

  return (
    <div>
      <PageHeader
        eyebrow="Your animals"
        title="My pets"
        subtitle="Manage your animals and their health records."
        actions={
          <Button onClick={() => navigate('/pets/new')}>
            <Plus size={18} /> Add pet
          </Button>
        }
      />

      {pets.length > 0 && (
        <div className="relative mb-6 max-w-sm">
          <Search
            size={16}
            className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground"
          />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search pets…"
            className="h-11 w-full rounded-(--radius-md) border border-input bg-card pl-9 pr-3 text-sm text-foreground placeholder:text-muted-foreground/70 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring"
          />
        </div>
      )}

      {loading ? (
        <PageSpinner />
      ) : filtered.length === 0 ? (
        <EmptyState
          icon={<PawPrint size={40} />}
          title={search ? 'No pets found' : 'No pets yet'}
          description={
            search
              ? 'Try a different search term.'
              : 'Add your first pet to start tracking symptoms, medications and appointments.'
          }
          action={
            !search ? (
              <Button onClick={() => navigate('/pets/new')}>
                <Plus size={18} /> Add your first pet
              </Button>
            ) : undefined
          }
        />
      ) : (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {filtered.map((pet) => (
            <PetCard key={pet.id} pet={pet} />
          ))}
        </div>
      )}
    </div>
  );
}

function PetCard({ pet }: { pet: Pet }) {
  const subtitle = pet.breed || pet.species;
  return (
    <Link to={`/pets/${pet.id}`} className="group block">
      <Card className="overflow-hidden transition-[transform,box-shadow] group-hover:-translate-y-0.5 group-hover:shadow-(--shadow-md)">
        <div className="flex h-28 items-center justify-center bg-primary-light">
          {pet.photoUrl ? (
            <img
              src={pet.photoUrl}
              alt={pet.name}
              className="h-full w-full object-cover"
            />
          ) : (
            <span className="font-display text-5xl font-semibold leading-none text-primary/70">
              {pet.name.charAt(0).toUpperCase() || '?'}
            </span>
          )}
        </div>
        <div className="p-4">
          <p className="font-display text-lg font-semibold text-foreground">
            {pet.name}
          </p>
          {subtitle && (
            <p className="mt-0.5 text-sm text-muted-foreground">{subtitle}</p>
          )}
          <div className="mt-2 inline-flex items-center gap-1.5 text-xs text-muted-foreground">
            <Cake size={13} />
            {petAgeLabel(pet.dateOfBirth)}
          </div>
        </div>
      </Card>
    </Link>
  );
}
