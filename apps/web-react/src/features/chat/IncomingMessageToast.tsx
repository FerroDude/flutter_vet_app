import { useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { toast } from 'sonner';
import { useAuth } from '@/auth/AuthProvider';
import { useRooms } from '@/lib/chatService';
import {
  getActiveChatRoom,
  incomingBody,
  incomingNotice,
  incomingTitle,
} from './incomingMessage';
import { chatRoomPath } from './useSelectedChatRoom';

function notifyOs(title: string, body: string, open: () => void): void {
  if (typeof Notification === 'undefined') return;
  if (Notification.permission !== 'granted') return;
  if (document.hasFocus()) return;
  try {
    const n = new Notification(title, { body });
    n.onclick = () => {
      window.focus();
      n.close();
      open();
    };
  } catch {
    /* browser blocked it */
  }
}

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
