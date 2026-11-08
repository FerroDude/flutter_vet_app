/** Room the signed-in user is reading. Incoming toasts skip this room. */
let activeRoomId: string | null = null;

export function setActiveChatRoom(roomId: string | null): void {
  activeRoomId = roomId;
}

export function getActiveChatRoom(): string | null {
  return activeRoomId;
}

export function incomingNotice(input: {
  prevUnread: number;
  nextUnread: number;
  senderId?: string | null;
  uid: string;
  roomId: string;
  activeRoomId: string | null;
}): { show: boolean; count: number } {
  const count = input.nextUnread - input.prevUnread;
  const show =
    count > 0 &&
    Boolean(input.senderId) &&
    input.senderId !== input.uid &&
    input.activeRoomId !== input.roomId;
  return { show, count };
}

import { t } from '@/i18n';
import { notificationsMuted } from '@/lib/notifications';

export function incomingTitle(count: number): string {
  return t(count === 1 ? 'chat.newMsg.one' : 'chat.newMsg.other', { count });
}

/** Whitespace-collapsed text clipped with "…" — toast description style. */
export function clip(text: string, max = 80): string {
  const s = text.replace(/\s+/g, ' ').trim();
  return s.length > max ? `${s.slice(0, max - 1)}…` : s;
}

export function incomingBody(senderName: string, content: string): string {
  const clipped = clip(content);
  const name = senderName.trim();
  if (name && clipped) return `${name}: ${clipped}`;
  return name || clipped || t('chat.newMsg.one');
}

/** metadata.kind marking the chat message a client cancellation sends. */
export const CANCEL_KIND = 'appointment_cancelled';

/** metadata.kind marking the chat message the vet confirmation sends. */
export const CONFIRM_KIND = 'appointment_confirmed';

/** OS notification when the tab is unfocused and permission was granted. */
export function notifyOs(title: string, body: string, open: () => void): void {
  if (notificationsMuted()) return;
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
