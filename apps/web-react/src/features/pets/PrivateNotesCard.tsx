import { useMemo, useState } from 'react';
import { toast } from 'sonner';
import { Lock, Pencil, Trash2 } from 'lucide-react';
import { useCollection } from '@/lib/useFirestore';
import {
  addPrivateNote,
  deletePrivateNote,
  mapPrivateNote,
  privateNotesQuery,
  updatePrivateNote,
  type PrivateNote,
} from '@/lib/privateNotes';
import { Card, CardBody } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Textarea } from '@/components/ui/Textarea';
import { useConfirm } from '@/components/ui/Confirm';

const noteFmt = new Intl.DateTimeFormat('pt-PT', {
  day: 'numeric',
  month: 'short',
  year: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
  hourCycle: 'h23',
});

function errorText(e: unknown): string {
  return e instanceof Error ? e.message : 'Não foi possível guardar';
}

export function PrivateNotesCard({
  clientId,
  petId,
  vetId,
}: {
  clientId: string;
  petId: string;
  vetId: string;
}) {
  const q = useMemo(() => privateNotesQuery(clientId, petId), [clientId, petId]);
  const { data, loading } = useCollection<PrivateNote>(q, mapPrivateNote);
  const notes = useMemo(
    () =>
      data
        .filter((n) => n.text.trim())
        .sort((a, b) => (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0)),
    [data],
  );

  const confirm = useConfirm();
  const [draft, setDraft] = useState('');
  const [adding, setAdding] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editText, setEditText] = useState('');
  const [savingEdit, setSavingEdit] = useState(false);

  const add = async () => {
    const text = draft.trim();
    if (!text) return;
    setAdding(true);
    try {
      await addPrivateNote({ clientId, petId, text, vetId });
      setDraft('');
    } catch (e) {
      toast.error(errorText(e));
    } finally {
      setAdding(false);
    }
  };

  const saveEdit = async (noteId: string) => {
    const text = editText.trim();
    if (!text) return;
    setSavingEdit(true);
    try {
      await updatePrivateNote({ clientId, petId, noteId, text, vetId });
      setEditingId(null);
    } catch (e) {
      toast.error(errorText(e));
    } finally {
      setSavingEdit(false);
    }
  };

  const remove = async (note: PrivateNote) => {
    const ok = await confirm({
      title: 'Apagar nota?',
      description: 'Não dá para desfazer.',
      confirmLabel: 'Apagar',
      danger: true,
    });
    if (!ok) return;
    try {
      await deletePrivateNote(clientId, petId, note.id);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Não foi possível apagar');
    }
  };

  return (
    <Card className="mb-6">
      <CardBody className="space-y-4">
        <div>
          <p className="flex items-center gap-1.5 text-sm font-semibold text-foreground">
            <Lock size={14} /> Notas privadas
          </p>
          <p className="text-xs text-muted-foreground">Só a veterinária vê estas notas. O cliente não.</p>
        </div>

        <div className="space-y-2">
          <Textarea
            label="Nova nota"
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) void add();
            }}
            placeholder="Observação, diagnóstico, lembrete…"
          />
          <div className="flex justify-end">
            <Button loading={adding} disabled={!draft.trim()} onClick={() => void add()}>
              Adicionar nota
            </Button>
          </div>
        </div>

        {loading && notes.length === 0 ? null : notes.length === 0 ? (
          <p className="text-sm text-muted-foreground">Ainda sem notas.</p>
        ) : (
          <ul className="divide-y divide-border rounded-(--radius-md) border border-border">
            {notes.map((n) => (
              <li key={n.id} className="p-3">
                {editingId === n.id ? (
                  <div className="space-y-2">
                    <Textarea
                      label="Editar nota"
                      value={editText}
                      onChange={(e) => setEditText(e.target.value)}
                      autoFocus
                    />
                    <div className="flex justify-end gap-2">
                      <Button variant="outline" disabled={savingEdit} onClick={() => setEditingId(null)}>
                        Cancelar
                      </Button>
                      <Button
                        loading={savingEdit}
                        disabled={!editText.trim()}
                        onClick={() => void saveEdit(n.id)}
                      >
                        Guardar
                      </Button>
                    </div>
                  </div>
                ) : (
                  <div className="flex items-start gap-3">
                    <div className="min-w-0 flex-1">
                      <p className="whitespace-pre-wrap break-words text-sm text-foreground">{n.text}</p>
                      <p className="mt-1 text-xs text-muted-foreground">
                        {n.createdAt ? noteFmt.format(n.createdAt) : ''}
                        {n.updatedAt &&
                        n.createdAt &&
                        n.updatedAt.getTime() - n.createdAt.getTime() > 60_000
                          ? ` · editada ${noteFmt.format(n.updatedAt)}`
                          : ''}
                      </p>
                    </div>
                    <button
                      type="button"
                      onClick={() => {
                        setEditingId(n.id);
                        setEditText(n.text);
                      }}
                      className="shrink-0 rounded-(--radius-sm) p-1.5 text-muted-foreground hover:bg-secondary"
                      aria-label="Editar nota"
                    >
                      <Pencil size={15} />
                    </button>
                    <button
                      type="button"
                      onClick={() => void remove(n)}
                      className="shrink-0 rounded-(--radius-sm) p-1.5 text-muted-foreground hover:bg-secondary hover:text-destructive"
                      aria-label="Apagar nota"
                    >
                      <Trash2 size={15} />
                    </button>
                  </div>
                )}
              </li>
            ))}
          </ul>
        )}
      </CardBody>
    </Card>
  );
}
