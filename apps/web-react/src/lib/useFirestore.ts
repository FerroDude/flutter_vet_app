// Thin hooks wrapping Firestore real-time listeners. Mirrors the Flutter
// providers' stream-based approach: components subscribe to live data and
// re-render on changes.

import { useEffect, useState } from 'react';
import {
  onSnapshot,
  type Query,
  type DocumentReference,
  type DocumentData,
} from 'firebase/firestore';

interface QueryState<T> {
  data: T[];
  loading: boolean;
  error: Error | null;
}

/**
 * Subscribe to a Firestore query. Pass a stable query (memoize with useMemo on
 * its inputs) to avoid resubscribing every render.
 */
export function useCollection<T>(
  query: Query<DocumentData> | null,
  map: (id: string, data: DocumentData) => T,
): QueryState<T> {
  const [state, setState] = useState<QueryState<T>>({
    data: [],
    loading: true,
    error: null,
  });

  useEffect(() => {
    if (!query) {
      setState({ data: [], loading: false, error: null });
      return;
    }
    setState((s) => ({ ...s, loading: true }));
    const unsub = onSnapshot(
      query,
      (snap) => {
        setState({
          data: snap.docs.map((d) => map(d.id, d.data())),
          loading: false,
          error: null,
        });
      },
      (error) => setState({ data: [], loading: false, error }),
    );
    return unsub;
    // map is intentionally not a dependency; callers pass a stable mapper.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [query]);

  return state;
}

interface DocState<T> {
  data: T | null;
  loading: boolean;
  error: Error | null;
}

export function useDoc<T>(
  ref: DocumentReference<DocumentData> | null,
  map: (id: string, data: DocumentData) => T,
): DocState<T> {
  const [state, setState] = useState<DocState<T>>({
    data: null,
    loading: true,
    error: null,
  });

  useEffect(() => {
    if (!ref) {
      setState({ data: null, loading: false, error: null });
      return;
    }
    setState((s) => ({ ...s, loading: true }));
    const unsub = onSnapshot(
      ref,
      (snap) => {
        setState({
          data: snap.exists() ? map(snap.id, snap.data()) : null,
          loading: false,
          error: null,
        });
      },
      (error) => setState({ data: null, loading: false, error }),
    );
    return unsub;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ref]);

  return state;
}
