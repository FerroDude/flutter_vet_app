import { useMemo, useState } from 'react';
import { toast } from 'sonner';
import {
  ArrowLeft,
  MessageCircle,
  Hourglass,
  Check,
  Inbox,
} from 'lucide-react';
import { type ChatRoom, ChatRoomStatus } from '@vetplus/shared';
import { useAuth } from '@/auth/AuthProvider';
import { useCollection } from '@/lib/useFirestore';
import {
  staffRoomsQuery,
  clinicRoomsQuery,
  mapRoom,
  acceptChatRequest,
} from '@/lib/chatService';
import { PageHeader } from '@/components/ui/PageHeader';
import { Button } from '@/components/ui/Button';
import { Conversation } from '@/features/chat/Conversation';
import { useSelectedChatRoom } from '@/features/chat/useSelectedChatRoom';

const timeFmt = new Intl.DateTimeFormat('pt-PT', { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' });
const dateFmt = new Intl.DateTimeFormat('pt-PT', { month: 'short', day: 'numeric' });

function roomTime(d: Date): string {
  const today = new Date();
  return d.toDateString() === today.toDateString() ? timeFmt.format(d) : dateFmt.format(d);
}

export function StaffChatPage() {
  const { firebaseUser, profile, connectedClinic } = useAuth();
  const uid = firebaseUser?.uid ?? '';
  const clinicId = connectedClinic?.id ?? '';
  const staffName = profile?.displayName?.trim() || profile?.email || 'Veterinária';

  const myQ = useMemo(() => (uid ? staffRoomsQuery(uid) : null), [uid]);
  const { data: myRaw } = useCollection<ChatRoom>(myQ, mapRoom);
  const myRooms = useMemo(
    () =>
      [...myRaw]
        .filter((r) => r.isActive)
        .sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime()),
    [myRaw],
  );

  const clinicQ = useMemo(() => (clinicId ? clinicRoomsQuery(clinicId) : null), [clinicId]);
  const { data: clinicRaw } = useCollection<ChatRoom>(clinicQ, mapRoom);
  const pending = useMemo(
    () =>
      [...clinicRaw]
        .filter((r) => r.isActive && r.status === ChatRoomStatus.pending)
        .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime()),
    [clinicRaw],
  );

  const [selectedId, setSelectedId] = useSelectedChatRoom();
  const [accepting, setAccepting] = useState<string | null>(null);

  const selected =
    myRooms.find((r) => r.id === selectedId) ?? pending.find((r) => r.id === selectedId) ?? null;

  const accept = async (room: ChatRoom) => {
    setAccepting(room.id);
    try {
      await acceptChatRequest({ roomId: room.id, staffId: uid, staffName });
      setSelectedId(room.id);
      toast.success('Conversa aceite');
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Não foi possível aceitar a conversa');
    } finally {
      setAccepting(null);
    }
  };

  return (
    // Mobile: top bar + main top padding + bottom-nav padding. Desktop: main py-10.
    <div className="flex h-[calc(100dvh-12.25rem)] min-h-[22rem] flex-col lg:h-[calc(100dvh-5rem)]">
      <PageHeader eyebrow="Mensagens" title="Chat" subtitle="Conversas com os seus clientes." />

      <div className="flex min-h-0 flex-1 overflow-hidden rounded-(--radius-lg) border border-border bg-card">
        {/* List */}
        <aside
          className={
            'w-full shrink-0 overflow-y-auto border-border md:w-80 md:border-r ' +
            (selectedId ? 'hidden md:block' : 'block')
          }
        >
          {pending.length > 0 && (
            <div>
              <p className="px-4 pb-1 pt-3 text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">
                Pedidos pendentes
              </p>
              <ul className="divide-y divide-border">
                {pending.map((r) => (
                  <li key={r.id} className="px-4 py-3">
                    <button
                      type="button"
                      onClick={() => setSelectedId(r.id)}
                      className="flex w-full items-center gap-3 text-left"
                    >
                      <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-warning/15 text-warning">
                        <Hourglass size={18} />
                      </span>
                      <span className="min-w-0 flex-1">
                        <span className="block truncate font-medium text-foreground">
                          {r.petOwnerName || 'Cliente'}
                        </span>
                        <span className="block truncate text-xs text-muted-foreground">
                          {r.topic || r.requestDescription || 'Novo pedido de conversa'}
                        </span>
                      </span>
                    </button>
                    <Button
                      variant="outline"
                      loading={accepting === r.id}
                      onClick={() => void accept(r)}
                      className="mt-2 w-full"
                    >
                      <Check size={15} /> Aceitar
                    </Button>
                  </li>
                ))}
              </ul>
            </div>
          )}

          <p className="px-4 pb-1 pt-3 text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">
            Conversas
          </p>
          {myRooms.length === 0 ? (
            <div className="p-6 text-center text-sm text-muted-foreground">
              Sem conversas ativas.
            </div>
          ) : (
            <ul className="divide-y divide-border">
              {myRooms.map((r) => (
                <li key={r.id}>
                  <button
                    type="button"
                    onClick={() => setSelectedId(r.id)}
                    className={
                      'flex w-full items-center gap-3 px-4 py-3 text-left transition-colors hover:bg-secondary ' +
                      (r.id === selectedId ? 'bg-secondary' : '')
                    }
                  >
                    <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-primary-light text-primary">
                      <MessageCircle size={18} />
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className="flex items-center justify-between gap-2">
                        <span className="truncate font-medium text-foreground">
                          {r.petOwnerName || 'Cliente'}
                        </span>
                        <span className="shrink-0 text-[11px] text-muted-foreground">
                          {roomTime(r.updatedAt)}
                        </span>
                      </span>
                      <span className="flex items-center justify-between gap-2">
                        <span className="truncate text-xs text-muted-foreground">
                          {r.lastMessage?.content || r.topic || 'Ainda sem mensagens'}
                        </span>
                        {(r.unreadCounts[uid] ?? 0) > 0 && (
                          <span className="grid h-5 min-w-5 shrink-0 place-items-center rounded-full bg-primary px-1.5 text-[11px] font-semibold text-primary-foreground">
                            {r.unreadCounts[uid]}
                          </span>
                        )}
                      </span>
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </aside>

        {/* Conversation */}
        <section className={'min-w-0 flex-1 ' + (selectedId ? 'block' : 'hidden md:block')}>
          {selectedId ? (
            <div className="flex h-full flex-col">
              <button
                type="button"
                onClick={() => setSelectedId(null)}
                className="flex items-center gap-1.5 border-b border-border px-4 py-2 text-sm text-muted-foreground md:hidden"
              >
                <ArrowLeft size={16} /> Voltar
              </button>
              {selected && selected.status === ChatRoomStatus.pending && (
                <div className="flex flex-wrap items-center justify-between gap-3 border-b border-border bg-warning/10 px-4 py-2.5">
                  <p className="text-sm text-foreground">
                    Pedido pendente de {selected.petOwnerName || 'cliente'}.
                  </p>
                  <Button
                    loading={accepting === selected.id}
                    onClick={() => void accept(selected)}
                  >
                    <Check size={15} /> Aceitar
                  </Button>
                </div>
              )}
              <div className="min-h-0 flex-1">
                <Conversation roomId={selectedId} />
              </div>
            </div>
          ) : (
            <div className="hidden h-full flex-col items-center justify-center gap-2 p-10 text-center text-sm text-muted-foreground md:flex">
              <Inbox size={32} className="text-muted-foreground/60" />
              Escolha uma conversa.
            </div>
          )}
        </section>
      </div>
    </div>
  );
}
