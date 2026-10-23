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
import { PetAvatar } from '@/components/ui/PetAvatar';
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
        eyebrow="Os seus animais"
        title="Animais"
        subtitle="Os seus animais e os registos de saúde."
        actions={
          <Button onClick={() => navigate('/pets/new')}>
            <Plus size={18} /> Adicionar animal
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
            placeholder="Procurar animais…"
            className="h-11 w-full rounded-(--radius-md) border border-input bg-card pl-9 pr-3 text-sm text-foreground placeholder:text-muted-foreground/70 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring"
          />
        </div>
      )}

      {loading ? (
        <PageSpinner />
      ) : filtered.length === 0 ? (
        <EmptyState
          icon={<PawPrint size={40} />}
          title={search ? 'Nenhum animal encontrado' : 'Ainda sem animais'}
          description={
            search
              ? 'Tente outra pesquisa.'
              : 'Adicione o primeiro animal para registar sintomas, medicação e marcações.'
          }
          action={
            !search ? (
              <Button onClick={() => navigate('/pets/new')}>
                <Plus size={18} /> Adicionar animal
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
      <Card className="flex items-center gap-4 p-4 transition-[transform,box-shadow] group-hover:-translate-y-0.5 group-hover:shadow-(--shadow-md)">
        <PetAvatar pet={pet} size={64} />
        <div className="min-w-0 flex-1">
          <p className="truncate font-display text-lg font-semibold text-foreground">
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
