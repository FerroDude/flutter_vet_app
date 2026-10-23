import { useEffect, useMemo, useRef, useState } from 'react';
import { toast } from 'sonner';
import {
  Send,
  Paperclip,
  Mic,
  Square,
  Check,
  CheckCheck,
  FileText,
  Clock,
  CornerUpLeft,
  Copy,
  Trash2,
  MoreHorizontal,
  X,
} from 'lucide-react';
import { type ChatMessage, type ChatRoom, MessageType, MessageStatus } from '@vetplus/shared';
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
  parseReply,
  parseReactions,
  REACTION_EMOJIS,
} from '@/lib/chatService';
import { cn } from '@/lib/cn';
import { dayShortFmt, errorMessage, timeFmt } from '@/lib/format';
import { Spinner } from '@/components/Spinner';
import { Menu, type MenuItem } from '@/components/ui/Menu';
import { useConfirm } from '@/components/ui/Confirm';
import { setActiveChatRoom } from './incomingMessage';

function typeLabel(type: MessageType): string {
  switch (type) {
    case MessageType.image:
      return '📷 Foto';
    case MessageType.video:
      return '🎬 Vídeo';
    case MessageType.voice:
      return '🎤 Mensagem de voz';
    case MessageType.file:
      return '📎 Anexo';
    default:
      return '';
  }
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

  // Auto-scroll to newest.
  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight });
  }, [messages.length]);

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
      <div
        ref={scrollRef}
        className="min-h-0 flex-1 space-y-1 overflow-y-auto px-5 py-4"
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
            const showDay =
              !prev || prev.timestamp.toDateString() !== m.timestamp.toDateString();
            return (
              <div key={m.id}>
                {showDay && (
                  <div className="my-3 text-center text-xs text-muted-foreground">
                    {dayShortFmt.format(m.timestamp)}
                  </div>
                )}
                <MessageRow
                  message={m}
                  mine={m.senderId === uid}
                  uid={uid}
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
          className="max-h-32 min-h-[44px] flex-1 resize-none rounded-(--radius-lg) border border-input bg-card px-3.5 py-2.5 text-sm text-foreground focus-visible:border-ring focus-visible:outline-1 focus-visible:outline-offset-0 focus-visible:outline-ring"
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

interface MessageRowProps {
  message: ChatMessage;
  mine: boolean;
  uid: string;
  onReply: (m: ChatMessage) => void;
  onCopy: (m: ChatMessage) => void;
  onReact: (m: ChatMessage, emoji: string) => void;
  onDelete: (m: ChatMessage) => void;
  onJumpToReply: (id: string) => void;
}

function MessageRow({
  message: m,
  mine,
  uid,
  onReply,
  onCopy,
  onReact,
  onDelete,
  onJumpToReply,
}: MessageRowProps) {
  if (m.isDeleted) {
    return (
      <div className={cn('flex', mine ? 'justify-end' : 'justify-start')}>
        <div className="my-0.5 rounded-(--radius-lg) bg-secondary px-3.5 py-2 text-sm italic text-muted-foreground">
          Mensagem apagada
        </div>
      </div>
    );
  }

  const reply = parseReply(m);
  const reactions = parseReactions(m);
  const actions = (
    <MessageActions
      mine={mine}
      message={m}
      onReply={onReply}
      onCopy={onCopy}
      onReact={onReact}
      onDelete={onDelete}
    />
  );

  return (
    <div
      id={`msg-${m.id}`}
      className={cn(
        'group flex items-end gap-1.5 rounded-(--radius-lg) transition-shadow',
        mine ? 'justify-end' : 'justify-start',
      )}
    >
      {mine && actions}
      <div className={cn('flex max-w-[80%] flex-col', mine ? 'items-end' : 'items-start')}>
        <div
          className={cn(
            'my-0.5 rounded-(--radius-lg) px-3.5 py-2 text-sm',
            mine ? 'bg-primary text-primary-foreground' : 'bg-secondary text-foreground',
          )}
        >
          {reply && (
            <button
              type="button"
              onClick={() => onJumpToReply(reply.id)}
              className={cn(
                'mb-1.5 flex w-full flex-col gap-0.5 rounded-(--radius-sm) border-l-2 px-2 py-1 text-left',
                mine
                  ? 'border-primary-foreground/60 bg-primary-foreground/15'
                  : 'border-primary bg-foreground/5',
              )}
            >
              <span
                className={cn(
                  'text-[11px] font-semibold',
                  mine ? 'text-primary-foreground/90' : 'text-primary',
                )}
              >
                {reply.senderId === uid ? 'Eu' : reply.senderName}
              </span>
              <span
                className={cn(
                  'truncate text-[11px]',
                  mine ? 'text-primary-foreground/75' : 'text-muted-foreground',
                )}
              >
                {reply.type === MessageType.text ? reply.content : typeLabel(reply.type)}
              </span>
            </button>
          )}
          <MessageContent message={m} mine={mine} />
          <div
            className={cn(
              'mt-1 flex items-center justify-end gap-1 text-[10px]',
              mine ? 'text-primary-foreground/70' : 'text-muted-foreground',
            )}
          >
            {timeFmt.format(m.timestamp)}
            {mine && <StatusTicks status={m.status} />}
          </div>
        </div>

        {reactions.length > 0 && (
          <div className={cn('mb-0.5 flex flex-wrap gap-1', mine ? 'justify-end' : 'justify-start')}>
            {reactions.map((r) => {
              const reacted = r.userIds.includes(uid);
              return (
                <button
                  key={r.emoji}
                  type="button"
                  onClick={() => onReact(m, r.emoji)}
                  title={r.userNames.join(', ')}
                  className={cn(
                    'inline-flex items-center gap-1 rounded-(--radius-pill) border px-1.5 py-0.5 text-[11px] tabular-nums transition-colors',
                    reacted
                      ? 'border-primary bg-primary-light text-primary'
                      : 'border-border bg-card text-muted-foreground hover:bg-secondary',
                  )}
                >
                  <span className="text-xs leading-none">{r.emoji}</span>
                  {r.userIds.length}
                </button>
              );
            })}
          </div>
        )}
      </div>
      {!mine && actions}
    </div>
  );
}

function MessageActions({
  mine,
  message: m,
  onReply,
  onCopy,
  onReact,
  onDelete,
}: {
  mine: boolean;
  message: ChatMessage;
  onReply: (m: ChatMessage) => void;
  onCopy: (m: ChatMessage) => void;
  onReact: (m: ChatMessage, emoji: string) => void;
  onDelete: (m: ChatMessage) => void;
}) {
  const items: MenuItem[] = [
    { label: 'Responder', icon: <CornerUpLeft size={14} />, onClick: () => onReply(m) },
    ...(m.type === MessageType.text
      ? [{ label: 'Copiar', icon: <Copy size={14} />, onClick: () => onCopy(m) }]
      : []),
    ...(mine
      ? [{ label: 'Apagar', icon: <Trash2 size={14} />, danger: true, onClick: () => onDelete(m) }]
      : []),
  ];
  return (
    <div className="self-center">
      <Menu
        label="Ações da mensagem"
        trigger={<MoreHorizontal size={16} />}
        align={mine ? 'right' : 'left'}
        items={items}
        triggerClassName="h-7 w-7 lg:opacity-0 lg:group-hover:opacity-100 focus-visible:opacity-100 aria-expanded:opacity-100"
        header={(close) => (
          <>
            <div className="flex justify-around px-1 pb-1">
              {REACTION_EMOJIS.map((emoji) => (
                <button
                  key={emoji}
                  type="button"
                  onClick={() => {
                    close();
                    onReact(m, emoji);
                  }}
                  className="grid h-8 w-8 place-items-center rounded-full text-base hover:bg-secondary"
                  aria-label={`Reagir ${emoji}`}
                >
                  {emoji}
                </button>
              ))}
            </div>
            <div className="my-1 h-px bg-border" />
          </>
        )}
      />
    </div>
  );
}

function MessageContent({ message: m, mine }: { message: ChatMessage; mine: boolean }) {
  switch (m.type) {
    case MessageType.image:
      return m.mediaUrl ? (
        <a href={m.mediaUrl} target="_blank" rel="noreferrer">
          <img
            src={m.mediaUrl}
            alt="Imagem partilhada"
            className="max-h-64 max-w-full rounded-(--radius-md) object-cover"
          />
        </a>
      ) : (
        <span>{m.content}</span>
      );
    case MessageType.video:
      return m.mediaUrl ? (
        <video src={m.mediaUrl} controls className="max-h-64 max-w-full rounded-(--radius-md)" />
      ) : (
        <span>{m.content}</span>
      );
    case MessageType.voice:
      return m.mediaUrl ? (
        <audio src={m.mediaUrl} controls className="h-9 w-56 max-w-full" />
      ) : (
        <span>{m.content}</span>
      );
    case MessageType.file:
      return (
        <a
          href={m.mediaUrl ?? '#'}
          target="_blank"
          rel="noreferrer"
          className={`flex min-w-0 items-center gap-2 underline ${mine ? '' : 'text-primary'}`}
        >
          <FileText size={16} className="shrink-0" />
          <span className="break-all">{m.fileName ?? 'Anexo'}</span>
        </a>
      );
    default:
      return <span className="whitespace-pre-wrap break-words">{m.content}</span>;
  }
}

function StatusTicks({ status }: { status: MessageStatus }) {
  if (status === MessageStatus.read) return <CheckCheck size={13} className="text-info" />;
  if (status === MessageStatus.delivered) return <CheckCheck size={13} />;
  if (status === MessageStatus.sent) return <Check size={13} />;
  return <Clock size={11} />;
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
