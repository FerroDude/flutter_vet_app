import { MessageCircle } from 'lucide-react';
import { useAuth } from '@/auth/AuthProvider';
import { useRooms } from '@/lib/chatService';
import { PageHeader } from '@/components/ui/PageHeader';
import { EmptyState } from '@/components/ui/EmptyState';
import { Conversation } from './Conversation';
import { CHAT_PAGE_HEIGHT } from './chatLayout';

/** Client chat: one vet, one conversation — opened straight away. */
export function ChatPage() {
  const { firebaseUser } = useAuth();
  const { rooms, loading } = useRooms('petOwnerId', firebaseUser?.uid ?? '');
  const room = rooms[0];

  if (!loading && !room) {
    return (
      <div>
        <PageHeader title="Chat" subtitle="Mensagens com a sua veterinária." />
        <EmptyState
          icon={<MessageCircle size={36} />}
          title="Ainda sem conversa"
          description="A conversa aparece quando a veterinária o adicionar como cliente."
        />
      </div>
    );
  }

  return (
    <div className={CHAT_PAGE_HEIGHT}>
      <div className="h-full overflow-hidden rounded-(--radius-lg) border border-border bg-card">
        {room && <Conversation roomId={room.id} />}
      </div>
    </div>
  );
}
