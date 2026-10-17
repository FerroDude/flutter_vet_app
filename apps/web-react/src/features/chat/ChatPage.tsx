import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { toast } from 'sonner';
import {
  MessageSquarePlus,
  Building2,
  ArrowLeft,
  MessageCircle,
  Hourglass,
} from 'lucide-react';
import { type ChatRoom, ChatRoomStatus } from '@vetplus/shared';
import { useAuth } from '@/auth/AuthProvider';
import { useCollection } from '@/lib/useFirestore';
import { petOwnerRoomsQuery, mapRoom, createChatRequest } from '@/lib/chatService';
import { PageHeader } from '@/components/ui/PageHeader';
import { Button } from '@/components/ui/Button';
import { EmptyState } from '@/components/ui/EmptyState';
import { Dialog } from '@/components/ui/Dialog';
import { TextField } from '@/components/ui/TextField';
import { Textarea } from '@/components/ui/Textarea';
import { Conversation } from './Conversation';

const timeFmt = new Intl.DateTimeFormat(undefined, { hour: 'numeric', minute: '2-digit' });
const dateFmt = new Intl.DateTimeFormat(undefined, { month: 'short', day: 'numeric' });

function roomTime(d: Date): string {
  const today = new Date();
  return d.toDateString() === today.toDateString() ? timeFmt.format(d) : dateFmt.format(d);
}

export function ChatPage() {
  const { firebaseUser, profile, connectedClinic } = useAuth();
  const navigate = useNavigate();
  const uid = firebaseUser?.uid ?? '';

  const roomsQ = useMemo(() => (uid ? petOwnerRoomsQuery(uid) : null), [uid]);
  const { data: roomsRaw } = useCollection<ChatRoom>(roomsQ, mapRoom);
  const rooms = useMemo(
    () =>
      [...roomsRaw]
        .filter((r) => r.isActive)
        .sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime()),
    [roomsRaw],
  );

  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [requestOpen, setRequestOpen] = useState(false);

  if (!connectedClinic) {
    return (
      <div>
        <PageHeader eyebrow="Messages" title="Chat" subtitle="Message your clinic." />
        <EmptyState
          icon={<Building2 size={36} />}
          title="No clinic connected"
          description="Connect to a clinic to start a conversation."
          action={<Button onClick={() => navigate('/profile')}>Connect a clinic</Button>}
        />
      </div>
    );
  }

  const selected = rooms.find((r) => r.id === selectedId) ?? null;

  return (
    <div className="flex h-[calc(100dvh-7rem)] flex-col">
      <PageHeader
        title="Chat"
        subtitle={`Conversations with ${connectedClinic.name}.`}
        actions={
          <Button onClick={() => setRequestOpen(true)}>
            <MessageSquarePlus size={16} /> New chat
          </Button>
        }
      />

      <div className="flex min-h-0 flex-1 overflow-hidden rounded-(--radius-lg) border border-border bg-card">
        {/* Rooms list */}
        <aside
          className={
            'w-full shrink-0 overflow-y-auto border-border md:w-80 md:border-r ' +
            (selected ? 'hidden md:block' : 'block')
          }
        >
          {rooms.length === 0 ? (
            <div className="p-6 text-center text-sm text-muted-foreground">
              No conversations yet. Start one with “New chat”.
            </div>
          ) : (
            <ul className="divide-y divide-border">
              {rooms.map((r) => (
                <li key={r.id}>
                  <button
                    type="button"
                    onClick={() => setSelectedId(r.id)}
                    className={
                      'flex w-full items-center gap-3 px-4 py-3 text-left transition-colors hover:bg-secondary ' +
                      (r.id === selectedId ? 'bg-secondary' : '')
                    }
                  >
                    <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-primary-light text-primary">
                      {r.status === ChatRoomStatus.pending ? (
                        <Hourglass size={18} />
                      ) : (
                        <MessageCircle size={18} />
                      )}
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className="flex items-center justify-between gap-2">
                        <span className="truncate font-medium text-foreground">
                          {r.vetName?.trim() || r.topic || 'Clinic'}
                        </span>
                        <span className="shrink-0 text-[11px] text-muted-foreground">
                          {roomTime(r.updatedAt)}
                        </span>
                      </span>
                      <span className="flex items-center justify-between gap-2">
                        <span className="truncate text-xs text-muted-foreground">
                          {r.status === ChatRoomStatus.pending
                            ? 'Pending — waiting for clinic'
                            : r.lastMessage?.content || 'No messages yet'}
                        </span>
                        {(r.unreadCounts[uid] ?? 0) > 0 && (
                          <span className="grid h-5 min-w-5 shrink-0 place-items-center rounded-full bg-primary px-1.5 text-[11px] font-semibold text-primary-foreground">
                            {r.unreadCounts[uid]}
                          </span>
                        )}
                      </span>
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </aside>

        {/* Conversation */}
        <section className={'min-w-0 flex-1 ' + (selected ? 'block' : 'hidden md:block')}>
          {selected ? (
            <div className="flex h-full flex-col">
              <button
                type="button"
                onClick={() => setSelectedId(null)}
                className="flex items-center gap-1.5 border-b border-border px-4 py-2 text-sm text-muted-foreground md:hidden"
              >
                <ArrowLeft size={16} /> Back
              </button>
              <div className="min-h-0 flex-1">
                <Conversation roomId={selected.id} />
              </div>
            </div>
          ) : (
            <div className="hidden h-full items-center justify-center p-10 text-center text-sm text-muted-foreground md:flex">
              Select a conversation or start a new one.
            </div>
          )}
        </section>
      </div>

      <NewChatDialog
        open={requestOpen}
        onClose={() => setRequestOpen(false)}
        onCreate={async (title, description) => {
          const id = await createChatRequest({
            clinicId: connectedClinic.id,
            petOwnerId: uid,
            petOwnerName: profile?.displayName?.trim() || profile?.email || '',
            title,
            description: description || null,
          });
          setRequestOpen(false);
          setSelectedId(id);
          toast.success('Chat request sent');
        }}
      />
    </div>
  );
}

function NewChatDialog({
  open,
  onClose,
  onCreate,
}: {
  open: boolean;
  onClose: () => void;
  onCreate: (title: string, description: string) => Promise<void>;
}) {
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const submit = async () => {
    if (!title.trim()) {
      setError('Please add a short subject.');
      return;
    }
    setSaving(true);
    setError(null);
    try {
      await onCreate(title.trim(), description.trim());
      setTitle('');
      setDescription('');
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not start chat');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title="New conversation"
      description="Send a request to your clinic. A team member will reply here."
      footer={
        <>
          <Button variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button loading={saving} onClick={() => void submit()}>
            Send request
          </Button>
        </>
      }
    >
      <div className="space-y-4">
        <TextField
          label="Subject"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="e.g., Question about my dog's medication"
        />
        <Textarea
          label="Details (optional)"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder="Add any context that might help the clinic…"
        />
        {error && <p className="text-sm font-medium text-destructive">{error}</p>}
      </div>
    </Dialog>
  );
}
