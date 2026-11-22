import { useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/auth/AuthProvider';
import { useActiveClinic } from '@/app/ClinicProvider';
import { useClinicRooms, useRooms } from '@/lib/chatService';
import {
  CANCEL_KIND,
  CONFIRM_KIND,
  getActiveChatRoom,
  incomingBody,
  incomingNotice,
  incomingTitle,
  showAlert,
} from './incomingMessage';
import { chatRoomPath } from './useSelectedChatRoom';

/** Toast on the signed-in user when someone else sends a chat message. */
export function IncomingMessageToast() {
  const { firebaseUser, role } = useAuth();
  const navigate = useNavigate();
  const uid = firebaseUser?.uid ?? '';
  const { clinicId } = useActiveClinic();
  const staff = useClinicRooms(clinicId, uid);
  const client = useRooms('petOwnerId', uid);
  const rooms = role === 'vet' ? [...staff.mine, ...staff.pool] : client.rooms;
  const loading = role === 'vet' ? staff.loading : client.loading;
  const seen = useRef<Map<string, number> | null>(null);

  useEffect(() => {
    if (!uid || loading) return;
    if (!seen.current) {
      seen.current = new Map(
        rooms.map((r) => [r.id, r.unreadCounts[uid] ?? r.unreadCounts.pool ?? 0]),
      );
      return;
    }
    for (const room of rooms) {
      // A staff member's counter in a pool room lives under 'pool'.
      const next = room.unreadCounts[uid] ?? room.unreadCounts.pool ?? 0;
      const prev = seen.current.get(room.id) ?? 0;
      seen.current.set(room.id, next);
      // Cancellation/confirmation messages are surfaced by dedicated watchers
      // (CancelledAppointmentToast / ConfirmedRequestToast), not the generic toast.
      const kind = room.lastMessage?.metadata?.kind;
      if (kind === CANCEL_KIND || kind === CONFIRM_KIND) continue;
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
      showAlert({
        id: `msg-${room.id}`,
        title,
        description: body,
        duration: 12000,
        open,
      });
    }
  }, [rooms, loading, uid, navigate]);

  return null;
}
