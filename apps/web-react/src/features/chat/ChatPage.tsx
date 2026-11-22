import { useMemo, useState } from 'react';
import { toast } from 'sonner';
import { MessageCircle, Plus } from 'lucide-react';
import { useAuth } from '@/auth/AuthProvider';
import { useActiveClinic } from '@/app/ClinicProvider';
import { useRooms, createPoolRoom, createDirectedRoom } from '@/lib/chatService';
import { clientLabel } from '@/lib/clientService';
import { errorMessage } from '@/lib/format';
import { PageHeader } from '@/components/ui/PageHeader';
import { EmptyState } from '@/components/ui/EmptyState';
import { Button } from '@/components/ui/Button';
import { Dialog } from '@/components/ui/Dialog';
import { Conversation } from './Conversation';
import { useSelectedChatRoom } from './useSelectedChatRoom';
import { CHAT_PAGE_HEIGHT } from './chatLayout';
import { t } from '@/i18n';

/**
 * Client chat: rooms of the active clinic. One room opens straight away;
 * with several the client picks. "Nova conversa" lets them choose a vet —
 * or "any vet" (the pool) — and reuses an existing room when one exists.
 */
export function ChatPage() {
  const { firebaseUser, profile } = useAuth();
  const { clinicId, members } = useActiveClinic();
  const uid = firebaseUser?.uid ?? '';
  const { rooms: allRooms, loading } = useRooms('petOwnerId', uid);
  const rooms = allRooms.filter((r) => r.clinicId === clinicId);
  const [selectedId, setSelectedId] = useSelectedChatRoom();
  const [starting, setStarting] = useState(false);
  const [pickerOpen, setPickerOpen] = useState(false);
  const [pick, setPick] = useState('');

  const vets = useMemo(
    () =>
      [...members]
        .filter((m) => m.active)
        .sort((a, b) => a.displayName.localeCompare(b.displayName)),
    [members],
  );
  // With a single vet there's nothing to pick — the pool room is the only
  // conversation, so "Nova conversa" is hidden once a room exists.
  const canPickVet = vets.length > 1;

  const open =
    selectedId && rooms.some((r) => r.id === selectedId)
      ? selectedId
      : rooms.length === 1
        ? (rooms[0]?.id ?? null)
        : null;

  const ownerName = profile ? clientLabel(profile) : '';

  /** Open (or create) the room for a vet id — '' means the pool. */
  const openRoom = async (vetId: string) => {
    const vet = vets.find((m) => m.uid === vetId) ?? null;
    const existing = vet
      ? rooms.find((r) => r.vetId === vet.uid)
      : rooms.find((r) => r.vetId === null);
    if (existing) {
      setSelectedId(existing.id);
      return;
    }
    const id = vet
      ? await createDirectedRoom({
          clinicId,
          petOwnerId: uid,
          petOwnerName: ownerName,
          vetId: vet.uid,
          vetName: vet.displayName,
        })
      : await createPoolRoom({ clinicId, petOwnerId: uid, petOwnerName: ownerName });
    setSelectedId(id);
  };

  const start = async (vetId = '') => {
    setStarting(true);
    try {
      await openRoom(vetId);
      setPickerOpen(false);
      setPick('');
    } catch (e) {
      toast.error(errorMessage(e, t('chat.sendFailed')));
    } finally {
      setStarting(false);
    }
  };

  const newConversation = canPickVet ? () => setPickerOpen(true) : () => void start('');

  if (!loading && rooms.length === 0) {
    return (
      <div>
        <PageHeader title="Chat" subtitle={t('chat.withVet')} />
        <EmptyState
          icon={<MessageCircle size={36} />}
          title={t('chat.empty.title')}
          description={t('chat.empty.body')}
          action={
            <Button loading={starting} onClick={newConversation}>
              {t('chat.new')}
            </Button>
          }
        />
        <VetPicker
          open={pickerOpen}
          busy={starting}
          pick={pick}
          vets={vets}
          onPick={setPick}
          onClose={() => setPickerOpen(false)}
          onConfirm={() => void start(pick)}
        />
      </div>
    );
  }

  return (
    <div className={CHAT_PAGE_HEIGHT}>
      <div className="flex min-h-0 flex-1 overflow-hidden rounded-(--radius-lg) border border-border bg-card">
        {rooms.length > 1 && (
          <aside className="w-full shrink-0 overflow-y-auto md:block md:w-72 md:border-r md:border-border">
            {canPickVet && (
              <div className="border-b border-border p-2">
                <button
                  type="button"
                  onClick={newConversation}
                  className="flex w-full items-center gap-2 rounded-(--radius-md) px-3 py-2 text-sm font-medium text-primary hover:bg-secondary"
                >
                  <Plus size={16} /> {t('chat.new')}
                </button>
              </div>
            )}
            <ul className="divide-y divide-border">
              {rooms.map((r) => (
                <li key={r.id}>
                  <button
                    type="button"
                    onClick={() => setSelectedId(r.id)}
                    className="flex w-full items-center gap-3 px-4 py-3 text-left transition-colors hover:bg-secondary"
                  >
                    <span className="min-w-0 flex-1">
                      <span className="block truncate font-medium text-foreground">
                        {r.vetName || t('chat.waitingVet')}
                      </span>
                      <span className="block truncate text-xs text-muted-foreground">
                        {r.lastMessage?.content || t('chat.noMessages')}
                      </span>
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          </aside>
        )}
        <section className="flex min-h-0 min-w-0 flex-1 flex-col">
          {open ? (
            <>
              {canPickVet && rooms.length === 1 && (
                <div className="flex h-12 shrink-0 items-center justify-end border-b border-border px-3">
                  <Button variant="outline" size="sm" onClick={newConversation}>
                    <Plus size={15} /> {t('chat.new')}
                  </Button>
                </div>
              )}
              <div className="min-h-0 flex-1">
                <Conversation roomId={open} />
              </div>
            </>
          ) : (
            <div className="hidden h-full items-center justify-center p-10 text-sm text-muted-foreground md:flex">
              {t('chat.pickRoom')}
            </div>
          )}
        </section>
      </div>

      <VetPicker
        open={pickerOpen}
        busy={starting}
        pick={pick}
        vets={vets}
        onPick={setPick}
        onClose={() => setPickerOpen(false)}
        onConfirm={() => void start(pick)}
      />
    </div>
  );
}

type VetLite = { uid: string; displayName: string };

function VetPicker({
  open,
  busy,
  pick,
  vets,
  onPick,
  onClose,
  onConfirm,
}: {
  open: boolean;
  busy: boolean;
  pick: string;
  vets: VetLite[];
  onPick: (uid: string) => void;
  onClose: () => void;
  onConfirm: () => void;
}) {
  return (
    <Dialog
      open={open}
      onClose={() => (busy ? undefined : onClose())}
      title={t('chat.who')}
      footer={
        <>
          <Button variant="outline" disabled={busy} onClick={onClose}>
            {t('common.cancel')}
          </Button>
          <Button loading={busy} onClick={onConfirm}>
            {t('chat.new')}
          </Button>
        </>
      }
    >
      <div className="space-y-1" role="radiogroup" aria-label={t('chat.who')}>
        {[{ uid: '', displayName: t('requests.anyVet') }, ...vets].map((v) => (
          <label
            key={v.uid}
            className="flex cursor-pointer items-center gap-3 rounded-(--radius-md) px-3 py-2.5 text-sm text-foreground hover:bg-secondary"
          >
            <input
              type="radio"
              name="vet-pick"
              checked={pick === v.uid}
              onChange={() => onPick(v.uid)}
              className="h-4 w-4 accent-[hsl(var(--primary))]"
            />
            {v.displayName}
          </label>
        ))}
      </div>
    </Dialog>
  );
}
