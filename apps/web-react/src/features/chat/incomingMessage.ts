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

export function incomingTitle(count: number): string {
  return count === 1 ? 'Mensagem nova' : `${count} mensagens novas`;
}

export function incomingBody(senderName: string, content: string): string {
  const text = content.replace(/\s+/g, ' ').trim();
  const clipped = text.length > 80 ? `${text.slice(0, 79)}…` : text;
  const name = senderName.trim();
  if (name && clipped) return `${name}: ${clipped}`;
  return name || clipped || 'Mensagem nova';
}
