import { useMemo } from 'react';
import { ArrowLeft, MessageCircle, Hourglass } from 'lucide-react';
import { type ChatRoom, ChatRoomStatus } from '@vetplus/shared';
import { useAuth } from '@/auth/AuthProvider';
import { useCollection } from '@/lib/useFirestore';
import { petOwnerRoomsQuery, mapRoom } from '@/lib/chatService';
import { PageHeader } from '@/components/ui/PageHeader';
import { EmptyState } from '@/components/ui/EmptyState';
import { Conversation } from './Conversation';
import { useSelectedChatRoom } from './useSelectedChatRoom';

const timeFmt = new Intl.DateTimeFormat('pt-PT', { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' });
const dateFmt = new Intl.DateTimeFormat('pt-PT', { month: 'short', day: 'numeric' });

function roomTime(d: Date): string {
  const today = new Date();
  return d.toDateString() === today.toDateString() ? timeFmt.format(d) : dateFmt.format(d);
}

export function ChatPage() {
  const { firebaseUser, profile } = useAuth();
  const uid = firebaseUser?.uid ?? '';
  const vetId = profile?.vetId ?? '';

  const roomsQ = useMemo(() => (uid ? petOwnerRoomsQuery(uid) : null), [uid]);
  const { data: roomsRaw } = useCollection<ChatRoom>(roomsQ, mapRoom);
  const rooms = useMemo(
    () =>
      [...roomsRaw]
        .filter((r) => r.isActive)
        .sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime()),
    [roomsRaw],
  );

  const [selectedId, setSelectedId] = useSelectedChatRoom();

  if (!vetId) {
    return (
      <div>
        <PageHeader eyebrow="Mensagens" title="Chat" subtitle="Fale com a sua veterinária." />
        <EmptyState
          icon={<MessageCircle size={36} />}
          title="Sem veterinária"
          description="A veterinária adiciona-o como cliente. A conversa abre a seguir."
        />
      </div>
    );
  }

  const open = Boolean(selectedId);

  return (
    // Mobile: top bar + main top padding + bottom-nav padding. Desktop: main py-10.
    <div className="flex h-[calc(100dvh-12.25rem)] min-h-[22rem] flex-col lg:h-[calc(100dvh-5rem)]">
      <PageHeader
        title="Chat"
        subtitle="Mensagens com a sua veterinária."
      />

      <div className="flex min-h-0 flex-1 overflow-hidden rounded-(--radius-lg) border border-border bg-card">
        {/* Rooms list */}
        <aside
          className={
            'w-full shrink-0 overflow-y-auto border-border md:w-80 md:border-r ' +
            (open ? 'hidden md:block' : 'block')
          }
        >
          {rooms.length === 0 ? (
            <div className="p-6 text-center text-sm text-muted-foreground">
              Ainda sem conversa. Aparece quando a veterinária o adicionar.
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
                          {r.vetName?.trim() || r.topic || 'Veterinária'}
                        </span>
                        <span className="shrink-0 text-[11px] text-muted-foreground">
                          {roomTime(r.updatedAt)}
                        </span>
                      </span>
                      <span className="flex items-center justify-between gap-2">
                        <span className="truncate text-xs text-muted-foreground">
                          {r.status === ChatRoomStatus.pending
                            ? 'Pendente — à espera da veterinária'
                            : r.lastMessage?.content || 'Ainda sem mensagens'}
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
        <section className={'min-w-0 flex-1 ' + (open ? 'block' : 'hidden md:block')}>
          {selectedId ? (
            <div className="flex h-full flex-col">
              <button
                type="button"
                onClick={() => setSelectedId(null)}
                className="flex items-center gap-1.5 border-b border-border px-4 py-2 text-sm text-muted-foreground md:hidden"
              >
                <ArrowLeft size={16} /> Voltar
              </button>
              <div className="min-h-0 flex-1">
                <Conversation roomId={selectedId} />
              </div>
            </div>
          ) : (
            <div className="hidden h-full items-center justify-center p-10 text-center text-sm text-muted-foreground md:flex">
              Escolha a conversa.
            </div>
          )}
        </section>
      </div>
    </div>
  );
}
