import { useSearchParams } from 'react-router-dom';

export function chatRoomPath(roomId: string): string {
  return `/chat?room=${encodeURIComponent(roomId)}`;
}

/** Selected conversation lives in the URL so links and notifications open it. */
export function useSelectedChatRoom(): [string | null, (id: string | null) => void] {
  const [params, setParams] = useSearchParams();
  const selectedId = params.get('room');
  const setSelectedId = (id: string | null) => {
    const next = new URLSearchParams(params);
    if (id) next.set('room', id);
    else next.delete('room');
    setParams(next, { replace: true });
  };
  return [selectedId, setSelectedId];
}
