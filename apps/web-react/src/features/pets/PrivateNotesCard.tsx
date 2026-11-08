import { useMemo, useState } from 'react';
import { toast } from 'sonner';
import { Eye, Lock, Pencil, Trash2 } from 'lucide-react';
import { useCollection } from '@/lib/useFirestore';
import {
  addPrivateNote,
  deletePrivateNote,
  mapPrivateNote,
  privateNotesQuery,
  updatePrivateNote,
  type NoteKind,
  type PrivateNote,
} from '@/lib/privateNotes';
import { Card, CardBody } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Textarea } from '@/components/ui/Textarea';
import { useConfirm } from '@/components/ui/Confirm';
import { t, locale } from '@/i18n';

const noteFmt = new Intl.DateTimeFormat(locale, {
  day: 'numeric',
  month: 'short',
  year: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
  hourCycle: 'h23',
});

function errorText(e: unknown): string {
  return e instanceof Error ? e.message : t('errors.save');
}

export function PrivateNotesCard({
  clientId,
  petId,
  vetId = '',
  kind = 'private',
  readOnly = false,
}: {
  clientId: string;
  petId: string;
  vetId?: string;
  kind?: NoteKind;
  /** Owner view: list only, and the whole card hides when there are no notes. */
  readOnly?: boolean;
}) {
  const q = useMemo(() => privateNotesQuery(clientId, petId, kind), [clientId, petId, kind]);
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
      await addPrivateNote({ clientId, petId, text, vetId, kind });
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
      await updatePrivateNote({ clientId, petId, noteId, text, vetId, kind });
      setEditingId(null);
    } catch (e) {
      toast.error(errorText(e));
    } finally {
      setSavingEdit(false);
    }
  };

  const remove = async (note: PrivateNote) => {
    const ok = await confirm({
      title: t('notes.deleteTitle'),
      description: t('chat.noUndo'),
      confirmLabel: t('common.delete'),
      danger: true,
    });
    if (!ok) return;
    try {
      await deletePrivateNote(clientId, petId, note.id, kind);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t('notes.deleteFailed'));
    }
  };

  if (readOnly && (loading || notes.length === 0)) return null;

  return (
    <Card className="mb-6">
      <CardBody className="space-y-4">
        <div>
          <p className="flex items-center gap-1.5 text-sm font-semibold text-foreground">
            {kind === 'public' ? <Eye size={14} /> : <Lock size={14} />}{' '}
            {kind === 'public' ? t('notes.public') : t('notes.private')}
          </p>
          {kind === 'public' && (
            <p className="mt-0.5 text-xs text-muted-foreground">{t('notes.publicHint')}</p>
          )}
        </div>

        {!readOnly && (
          <div className="space-y-2">
            <Textarea
              label={t('notes.new')}
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) void add();
              }}
              placeholder={t('notes.placeholder')}
            />
            <div className="flex justify-end">
              <Button loading={adding} disabled={!draft.trim()} onClick={() => void add()}>
                {t('notes.add')}
              </Button>
            </div>
          </div>
        )}

        {loading && notes.length === 0 ? null : notes.length === 0 ? (
          <p className="text-sm text-muted-foreground">{t('notes.empty')}</p>
        ) : (
          <ul className="divide-y divide-border rounded-(--radius-md) border border-border">
            {notes.map((n) => (
              <li key={n.id} className="p-3">
                {!readOnly && editingId === n.id ? (
                  <div className="space-y-2">
                    <Textarea
                      label={t('notes.edit')}
                      value={editText}
                      onChange={(e) => setEditText(e.target.value)}
                      autoFocus
                    />
                    <div className="flex justify-end gap-2">
                      <Button variant="outline" disabled={savingEdit} onClick={() => setEditingId(null)}>
                        {t('common.cancel')}
                      </Button>
                      <Button
                        loading={savingEdit}
                        disabled={!editText.trim()}
                        onClick={() => void saveEdit(n.id)}
                      >
                        {t('common.save')}
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
                          ? ` · ${t('notes.edited', { date: noteFmt.format(n.updatedAt) })}`
                          : ''}
                      </p>
                    </div>
                    {!readOnly && (
                      <>
                        <button
                          type="button"
                          onClick={() => {
                            setEditingId(n.id);
                            setEditText(n.text);
                          }}
                          className="shrink-0 rounded-(--radius-sm) p-1.5 text-muted-foreground hover:bg-secondary"
                          aria-label={t('notes.edit')}
                        >
                          <Pencil size={15} />
                        </button>
                        <button
                          type="button"
                          onClick={() => void remove(n)}
                          className="shrink-0 rounded-(--radius-sm) p-1.5 text-muted-foreground hover:bg-secondary hover:text-destructive"
                          aria-label={t('notes.delete')}
                        >
                          <Trash2 size={15} />
                        </button>
                      </>
                    )}
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
