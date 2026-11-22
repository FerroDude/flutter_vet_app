import { useState } from 'react';
import { toast } from 'sonner';
import { MessageCircle } from 'lucide-react';
import { useAuth } from '@/auth/AuthProvider';
import { useActiveClinic } from '@/app/ClinicProvider';
import { useRooms, createPoolRoom } from '@/lib/chatService';
import { clientLabel } from '@/lib/clientService';
import { errorMessage } from '@/lib/format';
import { PageHeader } from '@/components/ui/PageHeader';
import { EmptyState } from '@/components/ui/EmptyState';
import { Button } from '@/components/ui/Button';
import { Conversation } from './Conversation';
import { useSelectedChatRoom } from './useSelectedChatRoom';
import { CHAT_PAGE_HEIGHT } from './chatLayout';
import { t } from '@/i18n';

/**
 * Client chat: rooms of the active clinic. One room opens straight away;
 * with several the client picks, and none offers "Iniciar conversa" (pool).
 */
export function ChatPage() {
  const { firebaseUser, profile } = useAuth();
  const { clinicId } = useActiveClinic();
  const uid = firebaseUser?.uid ?? '';
  const { rooms: allRooms, loading } = useRooms('petOwnerId', uid);
  const rooms = allRooms.filter((r) => r.clinicId === clinicId);
  const [selectedId, setSelectedId] = useSelectedChatRoom();
  const [starting, setStarting] = useState(false);

  const open =
    selectedId && rooms.some((r) => r.id === selectedId)
      ? selectedId
      : rooms.length === 1
        ? (rooms[0]?.id ?? null)
        : null;

  const start = async () => {
    setStarting(true);
    try {
      const id = await createPoolRoom({
        clinicId,
        petOwnerId: uid,
        petOwnerName: profile ? clientLabel(profile) : '',
      });
      setSelectedId(id);
    } catch (e) {
      toast.error(errorMessage(e, t('chat.sendFailed')));
    } finally {
      setStarting(false);
    }
  };

  if (!loading && rooms.length === 0) {
    return (
      <div>
        <PageHeader title="Chat" subtitle={t('chat.withVet')} />
        <EmptyState
          icon={<MessageCircle size={36} />}
          title={t('chat.empty.title')}
          description={t('chat.empty.body')}
          action={
            <Button loading={starting} onClick={() => void start()}>
              {t('chat.start')}
            </Button>
          }
        />
      </div>
    );
  }

  return (
    <div className={CHAT_PAGE_HEIGHT}>
      <div className="flex min-h-0 flex-1 overflow-hidden rounded-(--radius-lg) border border-border bg-card">
        {rooms.length > 1 && (
          <aside className="w-full shrink-0 overflow-y-auto md:block md:w-72 md:border-r md:border-border">
            <ul className="divide-y divide-border">
              {rooms.map((r) => (
                <li key={r.id}>
                  <button
                    type="button"
                    onClick={() => setSelectedId(r.id)}
                    className="flex w-full items-center gap-3 px-4 py-3 text-left transition-colors hover:bg-secondary"
                  >
                    <span className="min-w-0 flex-1">
                      <span className="block truncate font-medium text-foreground">
                        {r.vetName || t('chat.waitingVet')}
                      </span>
                      <span className="block truncate text-xs text-muted-foreground">
                        {r.lastMessage?.content || t('chat.noMessages')}
                      </span>
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          </aside>
        )}
        <section className="min-w-0 flex-1">
          {open ? (
            <Conversation roomId={open} />
          ) : (
            <div className="hidden h-full items-center justify-center p-10 text-sm text-muted-foreground md:flex">
              {t('chat.pickRoom')}
            </div>
          )}
        </section>
      </div>
    </div>
  );
}
