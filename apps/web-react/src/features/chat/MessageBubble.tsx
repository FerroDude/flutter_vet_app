import { useRef, type Ref } from 'react';
import {
  Check,
  CheckCheck,
  Clock,
  CornerUpLeft,
  Copy,
  FileText,
  MoreHorizontal,
  Trash2,
} from 'lucide-react';
import { type ChatMessage, MessageType, MessageStatus } from '@vetplus/shared';
import { cn } from '@/lib/cn';
import { timeFmt } from '@/lib/format';
import { Menu, type MenuHandle, type MenuItem } from '@/components/ui/Menu';
import {
  parseReply,
  parseReactions,
  REACTION_EMOJIS,
} from '@/lib/chatService';
import { useSwipeReply } from './useSwipeReply';
import { useLongPress } from './useLongPress';

export function typeLabel(type: MessageType): string {
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

interface MessageBubbleProps {
  message: ChatMessage;
  mine: boolean;
  uid: string;
  groupStart: boolean;
  className?: string;
  onReply: (m: ChatMessage) => void;
  onCopy: (m: ChatMessage) => void;
  onReact: (m: ChatMessage, emoji: string) => void;
  onDelete: (m: ChatMessage) => void;
  onJumpToReply: (id: string) => void;
}

export function MessageBubble({
  message: m,
  mine,
  uid,
  groupStart,
  className,
  onReply,
  onCopy,
  onReact,
  onDelete,
  onJumpToReply,
}: MessageBubbleProps) {
  const reply = m.isDeleted ? null : parseReply(m);
  const reactions = m.isDeleted ? [] : parseReactions(m);
  const menuRef = useRef<MenuHandle | null>(null);
  const bubbleRef = useRef<HTMLDivElement>(null);
  const swipe = useSwipeReply(() => onReply(m));
  // Touch devices: long-press opens the ⋯ menu anchored on the bubble.
  const longPress = useLongPress(() => {
    const r = bubbleRef.current?.getBoundingClientRect();
    if (r) menuRef.current?.openAt(r);
  });
  const hoverNone =
    typeof window !== 'undefined' && window.matchMedia('(hover: none)').matches;
  const rowHandlers = m.isDeleted
    ? {}
    : {
        onPointerDown: (e: React.PointerEvent<HTMLElement>) => {
          swipe.handlers.onPointerDown(e);
          longPress.onPointerDown(e);
        },
        onPointerMove: (e: React.PointerEvent<HTMLElement>) => {
          swipe.handlers.onPointerMove(e);
          longPress.onPointerMove(e);
        },
        onPointerUp: () => {
          swipe.handlers.onPointerUp();
          longPress.onPointerUp();
        },
        onPointerCancel: () => {
          swipe.handlers.onPointerCancel();
          longPress.onPointerCancel();
        },
      };
  const actionsProps = { onReply, onCopy, onReact, onDelete, menuRef };

  const bubbleTone = m.isDeleted
    ? 'bg-secondary text-muted-foreground italic'
    : mine
      ? 'bg-primary text-primary-foreground'
      : 'bg-card text-foreground shadow-(--shadow-sm)';
  const tailColor = m.isDeleted ? 'text-secondary' : mine ? 'text-primary' : 'text-card';

  const bubble = (
    <div
      id={`msg-${m.id}`}
      ref={bubbleRef}
      onContextMenu={hoverNone ? (e) => e.preventDefault() : undefined}
      className={cn(
        'relative max-w-full min-w-0 rounded-[18px] text-sm transition-shadow',
        hoverNone && 'select-none',
        isMediaType(m.type) && !m.isDeleted ? 'p-1' : 'px-3.5 py-2 leading-relaxed',
        bubbleTone,
        groupStart && (mine ? 'rounded-tr-none' : 'rounded-tl-none'),
      )}
    >
      {groupStart && (
        <svg
          aria-hidden
          width="8"
          height="8"
          className={cn('absolute top-0', tailColor, mine ? '-right-2' : '-left-2 -scale-x-100')}
        >
          <path d="M0 0 L8 0 L0 8 Z" fill="currentColor" />
        </svg>
      )}
      {reply && (
        <button
          type="button"
          onClick={() => onJumpToReply(reply.id)}
          className={cn(
            'mb-1.5 flex w-full min-w-0 flex-col gap-0.5 rounded-(--radius-sm) border-l-2 px-2 py-1 text-left',
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
              'line-clamp-2 text-[11px] break-words',
              mine ? 'text-primary-foreground/75' : 'text-muted-foreground',
            )}
          >
            {reply.type === MessageType.text ? reply.content : typeLabel(reply.type)}
          </span>
        </button>
      )}
      <BubbleBody m={m} mine={mine} />
      {reactions.length > 0 && (
        <div
          className={cn(
            'absolute -bottom-3 flex gap-1',
            mine ? 'right-2' : 'left-2',
          )}
        >
          {reactions.map((r) => {
            const reacted = r.userIds.includes(uid);
            return (
              <button
                key={r.emoji}
                type="button"
                onClick={() => onReact(m, r.emoji)}
                title={r.userNames.join(', ')}
                className={cn(
                  'inline-flex items-center gap-1 rounded-(--radius-pill) border px-1.5 py-0.5 text-[11px] tabular-nums shadow-(--shadow-sm) transition-colors',
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
  );

  return (
    <div className={cn('relative', className)}>
      <CornerUpLeft
        size={18}
        aria-hidden
        className="absolute top-1/2 left-3 -translate-y-1/2 text-muted-foreground"
        style={{ opacity: Math.min(swipe.offset / 60, 1) }}
      />
      <div
        {...rowHandlers}
        style={{
          transform: `translateX(${swipe.offset}px)`,
          transition: swipe.dragging ? 'none' : 'transform 200ms',
        }}
        className={cn(
          'group flex touch-pan-y items-end gap-1.5',
          mine ? 'justify-end' : 'justify-start',
          reactions.length > 0 && 'mb-3',
        )}
      >
        {mine && !m.isDeleted && <MessageActions mine={mine} message={m} {...actionsProps} />}
        <div className={cn('flex min-w-0 max-w-[80%] flex-col sm:max-w-[75%] lg:max-w-[65%]', mine ? 'items-end' : 'items-start')}>
          {bubble}
        </div>
        {!mine && !m.isDeleted && <MessageActions mine={mine} message={m} {...actionsProps} />}
      </div>
    </div>
  );
}

function isMediaType(t: MessageType): boolean {
  return t === MessageType.image || t === MessageType.video;
}

function Meta({ m, mine, className }: { m: ChatMessage; mine: boolean; className?: string }) {
  return (
    <span
      className={cn(
        'flex items-center justify-end gap-1 text-[10px]',
        mine ? 'text-primary-foreground/70' : 'text-muted-foreground',
        className,
      )}
    >
      {timeFmt.format(m.timestamp)}
      {mine && <StatusTicks status={m.status} />}
    </span>
  );
}

function BubbleBody({ m, mine }: { m: ChatMessage; mine: boolean }) {
  if (m.isDeleted) {
    return <span>Mensagem apagada</span>;
  }
  if (m.type === MessageType.text) {
    return (
      <>
        <span className="whitespace-pre-wrap break-words">{m.content}</span>
        {/* invisible spacer keeps the last line clear of the absolute meta */}
        <span aria-hidden className={cn('inline-block h-3 align-bottom', mine ? 'w-14' : 'w-10')} />
        <Meta m={m} mine={mine} className="absolute right-3.5 bottom-1.5" />
      </>
    );
  }
  if (isMediaType(m.type)) {
    return (
      <div className="relative">
        <MessageContent message={m} mine={mine} />
        <Meta
          m={m}
          mine={mine}
          className="absolute right-2 bottom-2 rounded-full bg-black/45 px-1.5 py-0.5 text-white"
        />
      </div>
    );
  }
  return (
    <>
      <MessageContent message={m} mine={mine} />
      <Meta m={m} mine={mine} className="mt-1" />
    </>
  );
}

function MessageActions({
  mine,
  message: m,
  onReply,
  onCopy,
  onReact,
  onDelete,
  menuRef,
}: {
  mine: boolean;
  message: ChatMessage;
  onReply: (m: ChatMessage) => void;
  onCopy: (m: ChatMessage) => void;
  onReact: (m: ChatMessage, emoji: string) => void;
  onDelete: (m: ChatMessage) => void;
  menuRef: Ref<MenuHandle>;
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
    // Hidden entirely on touch devices — long-press opens the same menu.
    <div className="flex items-center gap-0.5 self-center [@media(hover:none)]:hidden">
      <button
        type="button"
        aria-label="Responder"
        onClick={() => onReply(m)}
        className="grid h-7 w-7 place-items-center rounded-full text-muted-foreground hover:bg-secondary hover:text-foreground [@media(hover:hover)]:opacity-0 [@media(hover:hover)]:group-hover:opacity-100 focus-visible:opacity-100"
      >
        <CornerUpLeft size={15} />
      </button>
      <Menu
        ref={menuRef}
        label="Ações da mensagem"
        trigger={<MoreHorizontal size={16} />}
        align={mine ? 'right' : 'left'}
        items={items}
        triggerClassName="h-7 w-7 [@media(hover:hover)]:opacity-0 [@media(hover:hover)]:group-hover:opacity-100 focus-visible:opacity-100 aria-expanded:opacity-100"
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
            className="max-h-64 max-w-full rounded-[14px] object-cover"
          />
        </a>
      ) : (
        <span>{m.content}</span>
      );
    case MessageType.video:
      return m.mediaUrl ? (
        <video
          src={m.mediaUrl}
          controls
          className="max-h-64 max-w-full rounded-[14px]"
        />
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
