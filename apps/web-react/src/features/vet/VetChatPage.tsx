import { ArrowLeft, Inbox } from 'lucide-react';
import { useAuth } from '@/auth/AuthProvider';
import { useRooms } from '@/lib/chatService';
import { sameDay, shortDateFmt, timeFmt } from '@/lib/format';
import { cn } from '@/lib/cn';
import { Conversation } from '@/features/chat/Conversation';
import { useSelectedChatRoom } from '@/features/chat/useSelectedChatRoom';
import { CHAT_PAGE_HEIGHT } from '@/features/chat/chatLayout';

/** Vet chat: list of client conversations + the open one. */
export function VetChatPage() {
  const { firebaseUser } = useAuth();
  const uid = firebaseUser?.uid ?? '';
  const { rooms } = useRooms('vetId', uid);
  const [selectedId, setSelectedId] = useSelectedChatRoom();

  return (
    <div className={CHAT_PAGE_HEIGHT}>
      <div className="flex min-h-0 flex-1 overflow-hidden rounded-(--radius-lg) border border-border bg-card">
        <aside
          className={cn(
            'w-full shrink-0 overflow-y-auto border-border md:block md:w-80 md:border-r',
            selectedId ? 'hidden' : 'block',
          )}
        >
          <p className="px-4 pb-1 pt-4 font-display text-lg font-bold text-foreground">Conversas</p>
          {rooms.length === 0 ? (
            <p className="p-6 text-center text-sm text-muted-foreground">
              Sem conversas. Abrem quando adiciona um cliente.
            </p>
          ) : (
            <ul className="divide-y divide-border">
              {rooms.map((r) => {
                const unread = r.unreadCounts[uid] ?? 0;
                return (
                  <li key={r.id}>
                    <button
                      type="button"
                      onClick={() => setSelectedId(r.id)}
                      className={cn(
                        'flex w-full items-center gap-3 px-4 py-3 text-left transition-colors hover:bg-secondary',
                        r.id === selectedId && 'bg-secondary',
                      )}
                    >
                      <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-primary-light font-semibold text-primary">
                        {(r.petOwnerName || '?').charAt(0).toUpperCase()}
                      </span>
                      <span className="min-w-0 flex-1">
                        <span className="flex items-center justify-between gap-2">
                          <span className="truncate font-medium text-foreground">{r.petOwnerName || 'Cliente'}</span>
                          <span className="shrink-0 text-[11px] text-muted-foreground">
                            {(sameDay(r.updatedAt, new Date()) ? timeFmt : shortDateFmt).format(r.updatedAt)}
                          </span>
                        </span>
                        <span className="flex items-center justify-between gap-2">
                          <span className="truncate text-xs text-muted-foreground">
                            {r.lastMessage?.content || 'Ainda sem mensagens'}
                          </span>
                          {unread > 0 && (
                            <span className="grid h-5 min-w-5 shrink-0 place-items-center rounded-full bg-primary px-1.5 text-[11px] font-semibold text-primary-foreground">
                              {unread}
                            </span>
                          )}
                        </span>
                      </span>
                    </button>
                  </li>
                );
              })}
            </ul>
          )}
        </aside>

        <section className={cn('min-w-0 flex-1 md:block', selectedId ? 'block' : 'hidden')}>
          {selectedId ? (
            <div className="flex h-full flex-col">
              <button
                type="button"
                onClick={() => setSelectedId(null)}
                className="flex items-center gap-1.5 border-b border-border px-4 py-2 text-sm text-muted-foreground md:hidden"
              >
                <ArrowLeft size={16} /> Conversas
              </button>
              <div className="min-h-0 flex-1">
                <Conversation roomId={selectedId} />
              </div>
            </div>
          ) : (
            <div className="hidden h-full flex-col items-center justify-center gap-2 p-10 text-center text-sm text-muted-foreground md:flex">
              <Inbox size={32} className="text-muted-foreground/60" />
              Escolha uma conversa.
            </div>
          )}
        </section>
      </div>
    </div>
  );
}
