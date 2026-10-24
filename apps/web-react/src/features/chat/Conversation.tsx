import { useEffect, useMemo, useRef, useState } from 'react';
import { toast } from 'sonner';
import { Send, Paperclip, Mic, Square, ChevronDown, X } from 'lucide-react';
import { type ChatMessage, type ChatRoom, MessageType } from '@vetplus/shared';
import { useAuth } from '@/auth/AuthProvider';
import { useDoc, useCollection } from '@/lib/useFirestore';
import {
  roomDoc,
  mapRoom,
  roomMessagesQuery,
  mapMessage,
  sendMessage,
  markRoomRead,
  markIncomingRead,
  uploadChatMedia,
  uploadChatVoice,
  messageTypeForFile,
  mediaPlaceholder,
  deleteMessage,
  toggleReaction,
  buildReplyMetadata,
} from '@/lib/chatService';
import { dayShortFmt, errorMessage, sameDay, startOfDay } from '@/lib/format';
import { Spinner } from '@/components/Spinner';
import { useConfirm } from '@/components/ui/Confirm';
import { setActiveChatRoom } from './incomingMessage';
import { MessageBubble, typeLabel } from './MessageBubble';

const GROUP_GAP_MS = 5 * 60 * 1000;

function dayChipLabel(d: Date): string {
  const today = startOfDay(new Date());
  const day = startOfDay(d);
  if (sameDay(day, today)) return 'Hoje';
  if (day.getTime() === today.getTime() - 86400000) return 'Ontem';
  return dayShortFmt.format(d);
}


function fmtDuration(sec: number): string {
  const m = Math.floor(sec / 60);
  const s = sec % 60;
  return `${m}:${`${s}`.padStart(2, '0')}`;
}

export function Conversation({ roomId }: { roomId: string }) {
  const { firebaseUser, profile, role } = useAuth();
  const uid = firebaseUser?.uid ?? '';
  const senderRole = role === 'vet' ? 'vet' : 'pet_owner';
  const confirm = useConfirm();

  const rDoc = useMemo(() => roomDoc(roomId), [roomId]);
  const { data: room } = useDoc<ChatRoom>(rDoc, mapRoom);

  const msgQ = useMemo(() => roomMessagesQuery(roomId), [roomId]);
  const { data: desc, loading } = useCollection<ChatMessage>(msgQ, mapMessage);
  const messages = useMemo(() => [...desc].reverse(), [desc]);

  const [text, setText] = useState('');
  const [sending, setSending] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [replyingTo, setReplyingTo] = useState<ChatMessage | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const scrollRef = useRef<HTMLDivElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  // Mark read when opening / when new messages arrive.
  useEffect(() => {
    if (!uid || !roomId) return;
    void markRoomRead(roomId, uid);
    void markIncomingRead(roomId, uid).catch(() => {});
  }, [roomId, uid, messages.length]);

  useEffect(() => {
    setActiveChatRoom(roomId);
    return () => setActiveChatRoom(null);
  }, [roomId]);

  // Scroll tracking: stick to bottom only when already near it (or own message).
  const [showJump, setShowJump] = useState(false);
  const [pendingCount, setPendingCount] = useState(0);
  const nearBottom = useRef(true);
  const firstScrollDone = useRef(false);
  const prevLen = useRef(0);

  const onScroll = () => {
    const el = scrollRef.current;
    if (!el) return;
    const dist = el.scrollHeight - el.scrollTop - el.clientHeight;
    nearBottom.current = dist <= 120;
    setShowJump(dist > 200);
    if (dist <= 120) setPendingCount(0);
  };

  const scrollToBottom = (smooth = false) => {
    const el = scrollRef.current;
    if (!el) return;
    el.scrollTo({ top: el.scrollHeight, behavior: smooth ? 'smooth' : 'auto' });
  };

  // Auto-scroll to newest.
  useEffect(() => {
    const len = messages.length;
    if (!firstScrollDone.current) {
      if (len > 0 || !loading) {
        firstScrollDone.current = true;
        prevLen.current = len;
        scrollToBottom();
      }
      return;
    }
    if (len > prevLen.current) {
      const newest = messages[len - 1];
      if (nearBottom.current || newest?.senderId === uid) {
        scrollToBottom();
        setPendingCount(0);
      } else {
        setPendingCount((c) => c + (len - prevLen.current));
      }
    }
    prevLen.current = len;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [messages.length, loading, uid]);

  const senderName = profile?.displayName?.trim() || profile?.email || 'Eu';

  const takeReplyMeta = () =>
    replyingTo ? buildReplyMetadata(replyingTo) : null;

  const doSendText = async () => {
    const content = text.trim();
    if (!content || !uid) return;
    const metadata = takeReplyMeta();
    setText('');
    setSending(true);
    try {
      await sendMessage({
        roomId,
        senderId: uid,
        senderName,
        senderRole,
        content,
        type: MessageType.text,
        metadata,
      });
      setReplyingTo(null);
    } catch (e) {
      toast.error(errorMessage(e, 'Não foi possível enviar a mensagem'));
      setText(content);
    } finally {
      setSending(false);
    }
  };

  const onPickFile = async (file: File) => {
    if (!uid) return;
    const type = messageTypeForFile(file);
    const metadata = takeReplyMeta();
    setUploading(true);
    try {
      const up = await uploadChatMedia(file, roomId, uid);
      await sendMessage({
        roomId,
        senderId: uid,
        senderName,
        senderRole,
        content: mediaPlaceholder(type, up.fileName),
        type,
        mediaUrl: up.mediaUrl,
        fileName: up.fileName,
        fileSize: up.fileSize,
        mimeType: up.mimeType,
        metadata,
      });
      setReplyingTo(null);
    } catch (e) {
      toast.error(errorMessage(e, 'Não foi possível enviar o ficheiro'));
    } finally {
      setUploading(false);
    }
  };

  const recorder = useVoiceRecorder(async (blob, duration) => {
    if (!uid) return;
    const metadata = takeReplyMeta();
    setUploading(true);
    try {
      const up = await uploadChatVoice(blob, roomId, uid);
      await sendMessage({
        roomId,
        senderId: uid,
        senderName,
        senderRole,
        content: mediaPlaceholder(MessageType.voice, up.fileName),
        type: MessageType.voice,
        mediaUrl: up.mediaUrl,
        fileName: up.fileName,
        fileSize: up.fileSize,
        mimeType: up.mimeType,
        audioDuration: duration,
        metadata,
      });
      setReplyingTo(null);
    } catch (e) {
      toast.error(errorMessage(e, 'Não foi possível enviar a mensagem de voz'));
    } finally {
      setUploading(false);
    }
  });

  const onReply = (m: ChatMessage) => {
    setReplyingTo(m);
    textareaRef.current?.focus();
  };

  const onCopy = async (m: ChatMessage) => {
    try {
      await navigator.clipboard.writeText(m.content);
      toast.success('Copiado');
    } catch {
      toast.error('Não foi possível copiar');
    }
  };

  const onReact = async (m: ChatMessage, emoji: string) => {
    try {
      await toggleReaction(roomId, m.id, uid, senderName, emoji);
    } catch (e) {
      toast.error(errorMessage(e, 'Não foi possível reagir'));
    }
  };

  const onDelete = async (m: ChatMessage) => {
    const ok = await confirm({
      title: 'Apagar mensagem?',
      description: 'Não dá para desfazer.',
      confirmLabel: 'Apagar',
      danger: true,
    });
    if (!ok) return;
    try {
      await deleteMessage(roomId, m.id);
      toast.success('Mensagem apagada');
    } catch (e) {
      toast.error(errorMessage(e, 'Não foi possível apagar a mensagem'));
    }
  };

  const scrollToMessage = (id: string) => {
    const el = document.getElementById(`msg-${id}`);
    if (!el) return;
    el.scrollIntoView({ behavior: 'smooth', block: 'center' });
    el.classList.add('ring-2', 'ring-primary/50');
    setTimeout(() => el.classList.remove('ring-2', 'ring-primary/50'), 1200);
  };

  // Auto-grow composer (max ~max-h-32).
  useEffect(() => {
    const t = textareaRef.current;
    if (!t) return;
    t.style.height = 'auto';
    t.style.height = `${Math.min(t.scrollHeight, 128)}px`;
  }, [text]);

  const iAmVet = Boolean(room && uid === room.vetId);
  const otherName = iAmVet ? room?.petOwnerName?.trim() : room?.vetName?.trim();

  return (
    <div className="flex h-full min-h-0 flex-col">
      {/* Header */}
      <div className="flex items-center gap-3 border-b border-border px-5 py-3">
        <div className="min-w-0">
          <p className="truncate font-display text-lg font-bold text-foreground">
            {otherName || room?.topic || 'Conversa'}
          </p>
          <p className="truncate text-xs text-muted-foreground">
            {iAmVet ? 'Cliente' : 'A sua veterinária'}
          </p>
        </div>
      </div>

      {/* Messages */}
      <div className="relative min-h-0 flex-1">
        <div
          ref={scrollRef}
          onScroll={onScroll}
          className="h-full overflow-y-auto bg-secondary/40 px-5 py-4"
        >
          {loading && messages.length === 0 ? (
            <div className="flex h-full items-center justify-center">
              <Spinner size={28} />
            </div>
          ) : messages.length === 0 ? (
            <p className="py-10 text-center text-sm text-muted-foreground">
              Ainda sem mensagens.
            </p>
          ) : (
            messages.map((m, i) => {
              const prev = messages[i - 1];
              const showDay = !prev || !sameDay(prev.timestamp, m.timestamp);
              const grouped =
                Boolean(prev) &&
                !showDay &&
                prev!.senderId === m.senderId &&
                m.timestamp.getTime() - prev!.timestamp.getTime() <= GROUP_GAP_MS;
              return (
                <div key={m.id}>
                  {showDay && (
                    <div className="sticky top-1 z-10 my-3 flex justify-center">
                      <span className="rounded-full bg-card px-3 py-1 text-xs text-muted-foreground shadow-(--shadow-sm)">
                        {dayChipLabel(m.timestamp)}
                      </span>
                    </div>
                  )}
                  <MessageBubble
                    message={m}
                    mine={m.senderId === uid}
                    uid={uid}
                    groupStart={!grouped}
                    className={i === 0 && !showDay ? '' : grouped ? 'mt-0.5' : 'mt-3'}
                    onReply={onReply}
                    onCopy={onCopy}
                    onReact={onReact}
                    onDelete={onDelete}
                    onJumpToReply={scrollToMessage}
                  />
                </div>
              );
            })
          )}
        </div>
        {showJump && (
          <button
            type="button"
            aria-label="Ir para as mensagens mais recentes"
            onClick={() => scrollToBottom(true)}
            className="absolute right-5 bottom-3 grid h-10 w-10 place-items-center rounded-full bg-card text-muted-foreground shadow-(--shadow-md) hover:text-foreground"
          >
            <ChevronDown size={20} />
            {pendingCount > 0 && (
              <span className="absolute -top-1 -right-1 grid min-h-5 min-w-5 place-items-center rounded-full bg-primary px-1 text-[10px] font-semibold text-primary-foreground">
                {pendingCount}
              </span>
            )}
          </button>
        )}
      </div>

      {/* Reply preview */}
      {replyingTo && (
        <div className="flex items-center gap-3 border-t border-border bg-secondary/60 px-4 py-2">
          <div className="w-1 self-stretch rounded-full bg-primary" />
          <div className="min-w-0 flex-1">
            <p className="text-xs font-semibold text-primary">
              A responder a{' '}
              {replyingTo.senderId === uid ? 'si' : replyingTo.senderName}
            </p>
            <p className="truncate text-xs text-muted-foreground">
              {replyingTo.type === MessageType.text
                ? replyingTo.content
                : typeLabel(replyingTo.type)}
            </p>
          </div>
          <button
            type="button"
            aria-label="Cancelar resposta"
            onClick={() => setReplyingTo(null)}
            className="grid h-8 w-8 shrink-0 place-items-center rounded-full text-muted-foreground hover:bg-secondary hover:text-foreground"
          >
            <X size={16} />
          </button>
        </div>
      )}

      {/* Composer */}
      <div className="flex items-end gap-2 border-t border-border px-4 py-3">
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*,video/*,application/pdf"
          className="hidden"
          onChange={(e) => {
            const f = e.target.files?.[0];
            if (f) void onPickFile(f);
            e.target.value = '';
          }}
        />
        <button
          type="button"
          aria-label="Anexar ficheiro"
          disabled={uploading || recorder.recording}
          onClick={() => fileInputRef.current?.click()}
          className="grid h-11 w-11 shrink-0 place-items-center rounded-full text-muted-foreground hover:bg-secondary disabled:opacity-50"
        >
          <Paperclip size={20} />
        </button>

        <textarea
          ref={textareaRef}
          rows={1}
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
              e.preventDefault();
              void doSendText();
            }
          }}
          placeholder={recorder.recording ? 'A gravar…' : 'Escreva uma mensagem…'}
          disabled={recorder.recording}
          className="min-h-[44px] flex-1 resize-none overflow-y-auto rounded-3xl border border-input bg-card px-4 py-2.5 text-sm text-foreground focus-visible:border-ring focus-visible:outline-1 focus-visible:outline-offset-0 focus-visible:outline-ring"
        />

        {text.trim() ? (
          <button
            type="button"
            aria-label="Enviar"
            disabled={sending}
            onClick={() => void doSendText()}
            className="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-primary text-primary-foreground hover:bg-primary/90 disabled:opacity-50"
          >
            <Send size={18} />
          </button>
        ) : recorder.recording ? (
          <button
            type="button"
            aria-label="Parar e enviar"
            onClick={() => void recorder.stop()}
            className="grid h-11 shrink-0 place-items-center gap-1 rounded-full bg-destructive px-3 text-destructive-foreground"
          >
            <span className="flex items-center gap-1.5 text-sm tabular-nums">
              <Square size={14} /> {fmtDuration(recorder.duration)}
            </span>
          </button>
        ) : (
          <button
            type="button"
            aria-label="Gravar mensagem de voz"
            disabled={uploading}
            onClick={() => void recorder.start()}
            className="grid h-11 w-11 shrink-0 place-items-center rounded-full text-muted-foreground hover:bg-secondary disabled:opacity-50"
          >
            {uploading ? <Spinner size={18} /> : <Mic size={20} />}
          </button>
        )}
      </div>
    </div>
  );
}

/* ----------------------------- voice recorder ------------------------------ */

function useVoiceRecorder(onComplete: (blob: Blob, durationSec: number) => Promise<void>) {
  const [recording, setRecording] = useState(false);
  const [duration, setDuration] = useState(0);
  const mediaRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<BlobPart[]>([]);
  const startedAtRef = useRef(0);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const cleanup = () => {
    if (timerRef.current) clearInterval(timerRef.current);
    timerRef.current = null;
    mediaRef.current?.stream.getTracks().forEach((t) => t.stop());
    mediaRef.current = null;
  };

  const start = async () => {
    if (recording) return;
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const mr = new MediaRecorder(stream);
      chunksRef.current = [];
      mr.ondataavailable = (e) => {
        if (e.data.size > 0) chunksRef.current.push(e.data);
      };
      mr.onstop = () => {
        const seconds = Math.max(1, Math.round((Date.now() - startedAtRef.current) / 1000));
        const blob = new Blob(chunksRef.current, { type: mr.mimeType || 'audio/webm' });
        cleanup();
        setRecording(false);
        setDuration(0);
        void onComplete(blob, seconds);
      };
      mediaRef.current = mr;
      startedAtRef.current = Date.now();
      mr.start();
      setRecording(true);
      setDuration(0);
      timerRef.current = setInterval(() => {
        setDuration(Math.round((Date.now() - startedAtRef.current) / 1000));
      }, 500);
    } catch {
      toast.error('Acesso ao microfone recusado');
    }
  };

  const stop = async () => {
    mediaRef.current?.stop();
  };

  useEffect(() => () => cleanup(), []);

  return { recording, duration, start, stop };
}
