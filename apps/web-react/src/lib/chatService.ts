// Chat data layer (pet owner side). Mirrors
// apps/mobile-flutter/lib/services/chat_service.dart + media_service.dart.
//
// Storage:
//   chatRooms/{roomId}
//   chatRooms/{roomId}/messages/{messageId}
//   Firebase Storage: chats/{roomId}/media|voice/{senderId}/{file}
// Interop: dates as millisecondsSinceEpoch, enums as integer indices. The room's
// embedded `lastMessage` is the message JSON (no id), exactly like mobile.

import {
  collection,
  doc,
  addDoc,
  getDoc,
  getDocs,
  updateDoc,
  writeBatch,
  runTransaction,
  serverTimestamp,
  query,
  where,
  orderBy,
  limit as qLimit,
  type DocumentData,
} from 'firebase/firestore';
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import {
  type ChatRoom,
  type ChatMessage,
  MessageType,
  MessageStatus,
  ChatRoomStatus,
  parseDate,
  parseDateOptional,
} from '@vetplus/shared';
import { db, storage } from './firebase';

export const chatRoomsCol = () => collection(db, 'chatRooms');
export const roomDoc = (id: string) => doc(db, 'chatRooms', id);
export const messagesCol = (roomId: string) =>
  collection(db, 'chatRooms', roomId, 'messages');
export const messageDoc = (roomId: string, id: string) =>
  doc(db, 'chatRooms', roomId, 'messages', id);

/** Pet owner's rooms. Single-field query; isActive filter + sort done client-side
 *  to avoid a composite index. */
export function petOwnerRoomsQuery(uid: string) {
  return query(chatRoomsCol(), where('petOwnerId', '==', uid));
}

/** Rooms assigned to a staff member (vet/receptionist sit in the vetId slot).
 *  Single-field query; filter isActive + sort client-side. */
export function staffRoomsQuery(staffId: string) {
  return query(chatRoomsCol(), where('vetId', '==', staffId));
}

/** All rooms for a clinic (admin / pending-request triage). Single-field query;
 *  filter isActive/status + sort client-side. */
export function clinicRoomsQuery(clinicId: string) {
  return query(chatRoomsCol(), where('clinicId', '==', clinicId));
}

/** Newest `n` messages (desc); reverse in the UI for chronological display. */
export function roomMessagesQuery(roomId: string, n = 100) {
  return query(messagesCol(roomId), orderBy('timestamp', 'desc'), qLimit(n));
}

/* ------------------------------ (de)serialize ------------------------------ */

export function mapMessage(id: string, d: DocumentData): ChatMessage {
  return {
    id,
    chatId: (d.chatId as string) ?? '',
    senderId: (d.senderId as string) ?? '',
    senderName: (d.senderName as string) ?? '',
    senderRole: (d.senderRole as string) ?? 'pet_owner',
    content: (d.content as string) ?? '',
    type: (d.type as MessageType) ?? MessageType.text,
    status: (d.status as MessageStatus) ?? MessageStatus.sent,
    timestamp: parseDate(d.timestamp),
    deliveredAt: parseDateOptional(d.deliveredAt) ?? null,
    readAt: parseDateOptional(d.readAt) ?? null,
    mediaUrl: (d.mediaUrl as string | null) ?? (d.imageUrl as string | null) ?? null,
    thumbnailUrl: (d.thumbnailUrl as string | null) ?? null,
    fileName: (d.fileName as string | null) ?? null,
    fileSize: (d.fileSize as number | null) ?? null,
    mimeType: (d.mimeType as string | null) ?? null,
    audioDuration: (d.audioDuration as number | null) ?? null,
    appointmentId: (d.appointmentId as string | null) ?? null,
    medicationId: (d.medicationId as string | null) ?? null,
    metadata: (d.metadata as Record<string, unknown> | null) ?? null,
    isDeleted: Boolean(d.isDeleted),
    deletedAt: parseDateOptional(d.deletedAt) ?? null,
  };
}

export function mapRoom(id: string, d: DocumentData): ChatRoom {
  const lm = d.lastMessage as DocumentData | null | undefined;
  return {
    id,
    clinicId: (d.clinicId as string) ?? '',
    petOwnerId: (d.petOwnerId as string) ?? '',
    petOwnerName: (d.petOwnerName as string) ?? '',
    vetId: (d.vetId as string) ?? '',
    vetName: (d.vetName as string) ?? '',
    petIds: Array.isArray(d.petIds) ? (d.petIds as string[]) : [],
    lastMessage: lm ? mapMessage((lm.id as string) ?? '', lm) : null,
    unreadCounts:
      d.unreadCounts && typeof d.unreadCounts === 'object'
        ? (d.unreadCounts as Record<string, number>)
        : {},
    createdAt: parseDate(d.createdAt),
    updatedAt: parseDate(d.updatedAt),
    isActive: d.isActive !== false,
    topic: (d.topic as string | null) ?? null,
    status: (d.status as ChatRoomStatus) ?? ChatRoomStatus.active,
    requestDescription: (d.requestDescription as string | null) ?? null,
    initiatedBy: (d.initiatedBy as string | null) ?? null,
    staffRole: (d.staffRole as string | null) ?? null,
  };
}

function messageToJson(m: Omit<ChatMessage, 'id'>): DocumentData {
  return {
    chatId: m.chatId,
    senderId: m.senderId,
    senderName: m.senderName,
    senderRole: m.senderRole,
    content: m.content,
    type: m.type,
    status: m.status,
    timestamp: m.timestamp.getTime(),
    deliveredAt: m.deliveredAt ? m.deliveredAt.getTime() : null,
    readAt: m.readAt ? m.readAt.getTime() : null,
    mediaUrl: m.mediaUrl ?? null,
    thumbnailUrl: m.thumbnailUrl ?? null,
    fileName: m.fileName ?? null,
    fileSize: m.fileSize ?? null,
    mimeType: m.mimeType ?? null,
    audioDuration: m.audioDuration ?? null,
    appointmentId: m.appointmentId ?? null,
    medicationId: m.medicationId ?? null,
    metadata: m.metadata ?? null,
    isDeleted: m.isDeleted,
    deletedAt: m.deletedAt ? m.deletedAt.getTime() : null,
  };
}

/* --------------------------------- Rooms ----------------------------------- */

export interface CreateChatRequestInput {
  clinicId: string;
  petOwnerId: string;
  petOwnerName: string;
  title: string;
  description?: string | null;
  petIds?: string[];
}

/** Pet owner creates a pending chat request (no vet assigned yet). */
export async function createChatRequest(i: CreateChatRequestInput): Promise<string> {
  const now = Date.now();
  const data: DocumentData = {
    clinicId: i.clinicId,
    petOwnerId: i.petOwnerId,
    petOwnerName: i.petOwnerName,
    vetId: '',
    vetName: '',
    petIds: i.petIds ?? [],
    lastMessage: null,
    unreadCounts: {},
    createdAt: now,
    updatedAt: now,
    isActive: true,
    topic: i.title,
    status: ChatRoomStatus.pending,
    requestDescription: i.description ?? null,
    initiatedBy: 'pet_owner',
    staffRole: null,
  };
  const r = await addDoc(chatRoomsCol(), data);
  return r.id;
}

/** Pet owner cancels a still-pending request (deletes the room). */
export async function deleteChatRequest(roomId: string): Promise<void> {
  await runTransaction(db, async (tx) => {
    const r = roomDoc(roomId);
    const snap = await tx.get(r);
    if (!snap.exists()) throw new Error('Chat room no longer exists');
    const status = (snap.data().status as number) ?? ChatRoomStatus.active;
    if (status !== ChatRoomStatus.pending) {
      throw new Error('Only pending chat requests can be deleted');
    }
    tx.delete(r);
  });
}

export async function getRoom(roomId: string): Promise<ChatRoom | null> {
  const snap = await getDoc(roomDoc(roomId));
  return snap.exists() ? mapRoom(snap.id, snap.data()) : null;
}

/** Staff accepts a pending request → becomes the assigned vet, room goes active. */
export async function acceptChatRequest(args: {
  roomId: string;
  staffId: string;
  staffName: string;
}): Promise<void> {
  await runTransaction(db, async (tx) => {
    const r = roomDoc(args.roomId);
    const snap = await tx.get(r);
    if (!snap.exists()) throw new Error('Chat room no longer exists');
    const status = (snap.data().status as number) ?? ChatRoomStatus.active;
    if (status !== ChatRoomStatus.pending) {
      throw new Error('Chat request already accepted or closed');
    }
    tx.update(r, {
      vetId: args.staffId,
      vetName: args.staffName,
      status: ChatRoomStatus.active,
      updatedAt: serverTimestamp(),
    });
  });
}

/** Find an existing active 1:1 room (clinic+petOwner+staff) or create one.
 *  Used by staff to initiate / open a chat (e.g. from an appointment request). */
export async function findOrCreateOneOnOneChat(args: {
  clinicId: string;
  petOwnerId: string;
  petOwnerName: string;
  staffId: string;
  staffName: string;
  staffRole: string;
  petIds?: string[];
  topic?: string | null;
}): Promise<string> {
  const existing = await getDocs(
    query(
      chatRoomsCol(),
      where('clinicId', '==', args.clinicId),
      where('petOwnerId', '==', args.petOwnerId),
      where('vetId', '==', args.staffId),
    ),
  );
  const active = existing.docs.find((d) => d.data().isActive !== false);
  if (active) return active.id;

  const now = Date.now();
  const data: DocumentData = {
    clinicId: args.clinicId,
    petOwnerId: args.petOwnerId,
    petOwnerName: args.petOwnerName,
    vetId: args.staffId,
    vetName: args.staffName,
    petIds: args.petIds ?? [],
    lastMessage: null,
    unreadCounts: {},
    createdAt: now,
    updatedAt: now,
    isActive: true,
    topic: args.topic ?? null,
    status: ChatRoomStatus.active,
    requestDescription: null,
    initiatedBy: args.staffRole,
    staffRole: args.staffRole,
  };
  const r = await addDoc(chatRoomsCol(), data);
  return r.id;
}

/** Soft-close a room for both participants (isActive:false, status:closed). */
export async function closeChatRoom(roomId: string): Promise<void> {
  await updateDoc(roomDoc(roomId), {
    isActive: false,
    status: ChatRoomStatus.closed,
    updatedAt: serverTimestamp(),
  });
}

/* -------------------------------- Messages --------------------------------- */

export interface SendMessageInput {
  roomId: string;
  senderId: string;
  senderName: string;
  senderRole: string;
  content: string;
  type?: MessageType;
  mediaUrl?: string | null;
  thumbnailUrl?: string | null;
  fileName?: string | null;
  fileSize?: number | null;
  mimeType?: string | null;
  audioDuration?: number | null;
  metadata?: Record<string, unknown> | null;
}

export async function sendMessage(i: SendMessageInput): Promise<void> {
  const room = await getRoom(i.roomId);

  const message: Omit<ChatMessage, 'id'> = {
    chatId: i.roomId,
    senderId: i.senderId,
    senderName: i.senderName,
    senderRole: i.senderRole,
    content: i.content,
    type: i.type ?? MessageType.text,
    status: MessageStatus.sent,
    timestamp: new Date(),
    deliveredAt: null,
    readAt: null,
    mediaUrl: i.mediaUrl ?? null,
    thumbnailUrl: i.thumbnailUrl ?? null,
    fileName: i.fileName ?? null,
    fileSize: i.fileSize ?? null,
    mimeType: i.mimeType ?? null,
    audioDuration: i.audioDuration ?? null,
    appointmentId: null,
    medicationId: null,
    metadata: i.metadata ?? null,
    isDeleted: false,
    deletedAt: null,
  };
  const json = messageToJson(message);

  const batch = writeBatch(db);
  batch.set(doc(messagesCol(i.roomId)), json);

  if (room) {
    const unread: Record<string, number> = { ...room.unreadCounts };
    const otherId = i.senderId === room.petOwnerId ? room.vetId : room.petOwnerId;
    if (otherId) unread[otherId] = (unread[otherId] ?? 0) + 1;
    batch.update(roomDoc(i.roomId), {
      lastMessage: json,
      unreadCounts: unread,
      updatedAt: serverTimestamp(),
    });
  }

  await batch.commit();
}

/** Reset this user's unread counter for the room. */
export async function markRoomRead(roomId: string, uid: string): Promise<void> {
  await updateDoc(roomDoc(roomId), { [`unreadCounts.${uid}`]: 0 });
}

/** Promote incoming messages (from the other participant) to read + delivered. */
export async function markIncomingRead(roomId: string, uid: string): Promise<void> {
  const snap = await getDocs(query(messagesCol(roomId), where('senderId', '!=', uid)));
  if (snap.empty) return;
  const batch = writeBatch(db);
  let n = 0;
  snap.docs.forEach((d) => {
    const status = (d.data().status as number) ?? 0;
    if (status === MessageStatus.sent || status === MessageStatus.delivered) {
      batch.update(d.ref, { status: MessageStatus.read, readAt: serverTimestamp() });
      n++;
    }
  });
  if (n > 0) await batch.commit();
}

/** Soft-delete a message (sender only — enforced by rules too). */
export async function deleteMessage(roomId: string, messageId: string): Promise<void> {
  await updateDoc(messageDoc(roomId, messageId), {
    isDeleted: true,
    deletedAt: serverTimestamp(),
  });
}

/* ------------------------------ Reply & reactions ------------------------------ */
// Reply + reaction data live inside the message `metadata` map (freeform), so no
// schema change is needed and the shape stays interoperable with the Flutter app.

/** Emoji set offered for quick reactions (parity with mobile `kReactionEmojis`). */
export const REACTION_EMOJIS = ['👍', '❤️', '😂', '😮', '😢', '😡'] as const;

export interface ReplyInfo {
  id: string;
  senderId: string;
  senderName: string;
  content: string;
  type: MessageType;
}

export interface ReactionInfo {
  emoji: string;
  userIds: string[];
  userNames: string[];
}

/** Build the metadata fields that mark a message as a reply to `target`. */
export function buildReplyMetadata(target: ChatMessage): Record<string, unknown> {
  return {
    replyToId: target.id,
    replyToSenderId: target.senderId,
    replyToSenderName: target.senderName,
    replyToContent: target.content,
    replyToType: target.type,
  };
}

/** Extract reply info from a message's metadata, or null if it isn't a reply. */
export function parseReply(m: ChatMessage): ReplyInfo | null {
  const md = m.metadata;
  if (!md || md.replyToId == null) return null;
  return {
    id: String(md.replyToId),
    senderId: String(md.replyToSenderId ?? ''),
    senderName: String(md.replyToSenderName ?? ''),
    content: String(md.replyToContent ?? ''),
    type: (md.replyToType as MessageType) ?? MessageType.text,
  };
}

/** Extract reactions list from a message's metadata. */
export function parseReactions(m: ChatMessage): ReactionInfo[] {
  const r = m.metadata?.reactions;
  return Array.isArray(r) ? (r as ReactionInfo[]) : [];
}

/** Toggle the current user's `emoji` reaction on a message (mirrors mobile). */
export async function toggleReaction(
  roomId: string,
  messageId: string,
  uid: string,
  userName: string,
  emoji: string,
): Promise<void> {
  await runTransaction(db, async (tx) => {
    const ref = messageDoc(roomId, messageId);
    const snap = await tx.get(ref);
    if (!snap.exists()) throw new Error('Message not found');
    const data = snap.data();
    const metadata: Record<string, unknown> = { ...(data.metadata ?? {}) };
    const reactions: ReactionInfo[] = Array.isArray(metadata.reactions)
      ? (metadata.reactions as ReactionInfo[]).map((r) => ({
          emoji: r.emoji,
          userIds: [...(r.userIds ?? [])],
          userNames: [...(r.userNames ?? [])],
        }))
      : [];

    const idx = reactions.findIndex((r) => r.emoji === emoji);
    if (idx >= 0) {
      const r = reactions[idx]!;
      const ui = r.userIds.indexOf(uid);
      if (ui >= 0) {
        r.userIds.splice(ui, 1);
        if (ui < r.userNames.length) r.userNames.splice(ui, 1);
        if (r.userIds.length === 0) reactions.splice(idx, 1);
      } else {
        r.userIds.push(uid);
        r.userNames.push(userName);
      }
    } else {
      reactions.push({ emoji, userIds: [uid], userNames: [userName] });
    }

    metadata.reactions = reactions;
    tx.update(ref, { metadata });
  });
}

/* ------------------------------ Media upload ------------------------------- */

export interface UploadedMedia {
  mediaUrl: string;
  fileName: string;
  fileSize: number;
  mimeType: string;
}

function uid(): string {
  return typeof crypto !== 'undefined' && 'randomUUID' in crypto
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

/** Upload an image/video/file to chats/{roomId}/media/{senderId}/... */
export async function uploadChatMedia(
  file: File,
  roomId: string,
  senderId: string,
): Promise<UploadedMedia> {
  const fileName = `${uid()}_${file.name}`;
  const path = `chats/${roomId}/media/${senderId}/${fileName}`;
  const storageRef = ref(storage, path);
  await uploadBytes(storageRef, file, { contentType: file.type || undefined });
  const mediaUrl = await getDownloadURL(storageRef);
  return {
    mediaUrl,
    fileName: file.name,
    fileSize: file.size,
    mimeType: file.type || 'application/octet-stream',
  };
}

/** Upload a recorded voice blob to chats/{roomId}/voice/{senderId}/... */
export async function uploadChatVoice(
  blob: Blob,
  roomId: string,
  senderId: string,
): Promise<UploadedMedia> {
  const ext = blob.type.includes('mp4') ? 'm4a' : 'webm';
  const contentType = blob.type || 'audio/webm';
  const fileName = `${uid()}_voice.${ext}`;
  const path = `chats/${roomId}/voice/${senderId}/${fileName}`;
  const storageRef = ref(storage, path);
  await uploadBytes(storageRef, blob, { contentType });
  const mediaUrl = await getDownloadURL(storageRef);
  return { mediaUrl, fileName, fileSize: blob.size, mimeType: contentType };
}

/** Helper: which message kind a file maps to. */
export function messageTypeForFile(file: File): MessageType {
  if (file.type.startsWith('image/')) return MessageType.image;
  if (file.type.startsWith('video/')) return MessageType.video;
  return MessageType.file;
}

/** Placeholder content text shown for media messages (matches mobile). */
export function mediaPlaceholder(type: MessageType, fileName: string): string {
  switch (type) {
    case MessageType.image:
      return '📷 Photo';
    case MessageType.video:
      return '🎬 Video';
    case MessageType.voice:
      return '🎤 Voice message';
    default:
      return `📎 ${fileName}`;
  }
}
