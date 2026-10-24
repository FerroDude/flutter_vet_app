import { useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { toast } from 'sonner';
import { useAuth } from '@/auth/AuthProvider';
import { useRooms } from '@/lib/chatService';
import {
  CANCEL_KIND,
  getActiveChatRoom,
  incomingBody,
  incomingNotice,
  incomingTitle,
  notifyOs,
} from './incomingMessage';
import { chatRoomPath } from './useSelectedChatRoom';

/** Toast on the signed-in user when someone else sends a chat message. */
export function IncomingMessageToast() {
  const { firebaseUser, role } = useAuth();
  const navigate = useNavigate();
  const uid = firebaseUser?.uid ?? '';
  const { rooms, loading } = useRooms(role === 'vet' ? 'vetId' : 'petOwnerId', uid);
  const seen = useRef<Map<string, number> | null>(null);

  useEffect(() => {
    if (!uid || loading) return;
    if (!seen.current) {
      seen.current = new Map(rooms.map((r) => [r.id, r.unreadCounts[uid] ?? 0]));
      return;
    }
    for (const room of rooms) {
      const next = room.unreadCounts[uid] ?? 0;
      const prev = seen.current.get(room.id) ?? 0;
      seen.current.set(room.id, next);
      // Cancellation messages are surfaced by the dedicated watcher
      // (CancelledAppointmentToast) instead of the generic chat toast.
      if (room.lastMessage?.metadata?.kind === CANCEL_KIND) continue;
      const notice = incomingNotice({
        prevUnread: prev,
        nextUnread: next,
        senderId: room.lastMessage?.senderId,
        uid,
        roomId: room.id,
        activeRoomId: getActiveChatRoom(),
      });
      if (!notice.show || !room.lastMessage) continue;
      const title = incomingTitle(notice.count);
      const body = incomingBody(room.lastMessage.senderName, room.lastMessage.content);
      const open = () => navigate(chatRoomPath(room.id));
      toast(title, {
        id: `msg-${room.id}`,
        description: body,
        duration: 12000,
        action: { label: 'Abrir', onClick: open },
      });
      notifyOs(title, body, open);
    }
  }, [rooms, loading, uid, navigate]);

  return null;
}
