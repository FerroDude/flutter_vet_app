// Chat between a vet and one of her clients (one room per pair).
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
import { useMemo } from 'react';
import { db, storage } from './firebase';
import { useCollection } from './useFirestore';
import { t } from '@/i18n';

export const chatRoomsCol = () => collection(db, 'chatRooms');
export const roomDoc = (id: string) => doc(db, 'chatRooms', id);
export const messagesCol = (roomId: string) =>
  collection(db, 'chatRooms', roomId, 'messages');
export const messageDoc = (roomId: string, id: string) =>
  doc(db, 'chatRooms', roomId, 'messages', id);

/** A user's rooms (`petOwnerId` for a client, `vetId` for a vet). Single-field
 *  query; isActive filter + sort happen in useRooms to avoid a composite index. */
export function roomsQuery(field: 'petOwnerId' | 'vetId', uid: string) {
  return query(chatRoomsCol(), where(field, '==', uid));
}

/** Active rooms, most recent first, plus this user's unread total. */
export function useRooms(field: 'petOwnerId' | 'vetId', uid: string) {
  const q = useMemo(() => (uid ? roomsQuery(field, uid) : null), [field, uid]);
  const { data, loading } = useCollection(q, mapRoom);
  return useMemo(() => {
    const rooms = data
      .filter((r) => r.isActive)
      .sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime());
    const unread = rooms.reduce((n, r) => n + (r.unreadCounts[uid] ?? 0), 0);
    return { rooms, unread, loading };
  }, [data, loading, uid]);
}

/**
 * Staff chat: the vet's own rooms plus the clinic pool (unassigned).
 * unread = my counters + the number of pool rooms with unread pool messages.
 */
/** Staff unread total: my counters + pool rooms with unread pool messages. */
export function clinicRoomsUnread(mine: ChatRoom[], pool: ChatRoom[], uid: string): number {
  return (
    mine.reduce((n, r) => n + (r.unreadCounts[uid] ?? 0), 0) +
    pool.filter((r) => (r.unreadCounts.pool ?? 0) > 0).length
  );
}

export function useClinicRooms(clinicId: string, uid: string) {
  const mineQ = useMemo(
    () =>
      clinicId && uid
        ? query(chatRoomsCol(), where('clinicId', '==', clinicId), where('vetId', '==', uid))
        : null,
    [clinicId, uid],
  );
  const poolQ = useMemo(
    () =>
      clinicId
        ? query(chatRoomsCol(), where('clinicId', '==', clinicId), where('vetId', '==', null))
        : null,
    [clinicId],
  );
  const mine = useCollection(mineQ, mapRoom);
  const pool = useCollection(poolQ, mapRoom);
  return useMemo(() => {
    const sort = (rs: ChatRoom[]) =>
      rs.filter((r) => r.isActive).sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime());
    const m = sort(mine.data);
    const p = sort(pool.data);
    const unread = clinicRoomsUnread(m, p, uid);
    return { mine: m, pool: p, unread, loading: mine.loading || pool.loading };
  }, [mine.data, mine.loading, pool.data, pool.loading, uid]);
}

/**
 * Claim a pool room: assign it to me. Fails with 'chat.alreadyClaimed' if
 * another vet got there first (transaction guards the vetId == null race).
 */
export async function claimRoom(roomId: string, uid: string, vetName: string): Promise<void> {
  const ref = roomDoc(roomId);
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists()) throw new Error(t('chat.gone'));
    const d = snap.data();
    if (d.vetId) {
      throw new Error(t('chat.alreadyClaimed', { name: (d.vetName as string) || t('common.vet') }));
    }
    tx.update(ref, {
      vetId: uid,
      vetName,
      status: ChatRoomStatus.active,
      claimedAt: Date.now(),
      updatedAt: Date.now(),
    });
  });
  // The claim write may only touch assignment fields, so the pool's unread
  // counter moves to me in a second write (I'm the assignee now).
  const room = await getRoom(roomId);
  const poolN = room?.unreadCounts.pool ?? 0;
  if (poolN > 0) {
    await updateDoc(ref, {
      [`unreadCounts.${uid}`]: poolN,
      'unreadCounts.pool': 0,
    });
  }
}

/** Give my room back to the clinic pool ("pass to clinic"). */
export async function releaseRoom(roomId: string): Promise<void> {
  await updateDoc(roomDoc(roomId), {
    vetId: null,
    vetName: null,
    status: ChatRoomStatus.pending,
    releasedAt: Date.now(),
    updatedAt: Date.now(),
  });
}

/**
 * Client starts a chat with the clinic pool ("any vet"). Rules require
 * requestedVetId == vetId (both null) and status pending.
 */
export async function createPoolRoom(args: {
  clinicId: string;
  petOwnerId: string;
  petOwnerName: string;
}): Promise<string> {
  const now = Date.now();
  const r = await addDoc(chatRoomsCol(), {
    clinicId: args.clinicId,
    petOwnerId: args.petOwnerId,
    petOwnerName: args.petOwnerName,
    vetId: null,
    vetName: null,
    requestedVetId: null,
    petIds: [],
    lastMessage: null,
    unreadCounts: {},
    createdAt: now,
    updatedAt: now,
    isActive: true,
    topic: null,
    status: ChatRoomStatus.pending,
    requestDescription: null,
    initiatedBy: 'pet_owner',
    staffRole: 'vet',
  });
  return r.id;
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
    clinicId: (d.clinicId as string | null) ?? null,
    petOwnerId: (d.petOwnerId as string) ?? '',
    petOwnerName: (d.petOwnerName as string) ?? '',
    vetId: (d.vetId as string | null) ?? null,
    vetName: (d.vetName as string | null) ?? null,
    requestedVetId: (d.requestedVetId as string | null) ?? null,
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

export async function getRoom(roomId: string): Promise<ChatRoom | null> {
  const snap = await getDoc(roomDoc(roomId));
  return snap.exists() ? mapRoom(snap.id, snap.data()) : null;
}

/**
 * Find the client↔vet room in this clinic or create it. Staff-created rooms
 * are directed to the caller (vetId = me), never pooled.
 */
export async function findOrCreateOneOnOneChat(args: {
  clinicId: string;
  petOwnerId: string;
  petOwnerName: string;
  vetId: string;
  vetName: string;
}): Promise<string> {
  const existing = await getDocs(
    query(
      chatRoomsCol(),
      where('clinicId', '==', args.clinicId),
      where('vetId', '==', args.vetId),
      where('petOwnerId', '==', args.petOwnerId),
    ),
  );
  const active = existing.docs.find((d) => d.data().isActive !== false);
  if (active) return active.id;

  const now = Date.now();
  const r = await addDoc(chatRoomsCol(), {
    clinicId: args.clinicId,
    petOwnerId: args.petOwnerId,
    petOwnerName: args.petOwnerName,
    vetId: args.vetId,
    vetName: args.vetName,
    requestedVetId: args.vetId,
    petIds: [],
    lastMessage: null,
    unreadCounts: {},
    createdAt: now,
    updatedAt: now,
    isActive: true,
    topic: null,
    status: ChatRoomStatus.active,
    requestDescription: null,
    initiatedBy: 'vet',
    staffRole: 'vet',
  });
  return r.id;
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
    // The receiver is the other participant; a vet-less room counts under 'pool'
    // so every clinic vet sees the badge until someone claims it.
    const otherId = i.senderId === room.petOwnerId ? (room.vetId ?? 'pool') : room.petOwnerId;
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
    if (!snap.exists()) throw new Error(t('errors.msgNotFound'));
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
      return t('chat.type.image');
    case MessageType.video:
      return t('chat.type.video');
    case MessageType.voice:
      return t('chat.type.voice');
    default:
      return t('chat.type.file', { name: fileName });
  }
}
