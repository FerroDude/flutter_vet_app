import { afterEach, describe, expect, it, vi } from 'vitest';
import { deleteEvent, upsertEvent } from './google.js';

// firebase-admin/firestore is only needed by accessToken; google.ts imports it
// lazily at call time but the module import itself must not blow up in tests.
vi.mock('firebase-admin/firestore', () => ({ getFirestore: vi.fn() }));

interface FakeRes {
  ok?: boolean;
  status?: number;
  json?: unknown;
}

function fakeFetch(handler: (url: string, init?: RequestInit) => FakeRes) {
  return vi.fn(async (input: unknown, init?: RequestInit) => {
    const res = handler(String(input), init);
    return {
      ok: res.ok ?? true,
      status: res.status ?? 200,
      json: async () => res.json,
      text: async () => '',
    } as Response;
  });
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('upsertEvent', () => {
  it('inserts on 200', async () => {
    const calls: Array<{ url: string; init?: RequestInit }> = [];
    vi.stubGlobal(
      'fetch',
      fakeFetch((url, init) => {
        calls.push({ url, init });
        return { json: { id: 'x' } };
      }),
    );
    await upsertEvent('tok', 'cal@x', 'ev1', { summary: 'S' });
    expect(calls).toHaveLength(1);
    expect(calls[0].init?.method).toBe('POST');
    expect(JSON.parse(String(calls[0].init?.body))).toMatchObject({ id: 'ev1', summary: 'S' });
    expect(String(calls[0].init && (calls[0].init.headers as Record<string, string>).Authorization)).toBe(
      'Bearer tok',
    );
  });

  it('falls back to PUT on 409', async () => {
    const methods: string[] = [];
    vi.stubGlobal(
      'fetch',
      fakeFetch((url, init) => {
        methods.push(String(init?.method));
        if (init?.method === 'POST') {
          return { ok: false, status: 409, json: { error: { code: 409, message: 'duplicate' } } };
        }
        return { json: { id: 'ev1' } };
      }),
    );
    await upsertEvent('tok', 'cal@x', 'ev1', { summary: 'S' });
    expect(methods).toEqual(['POST', 'PUT']);
  });

  it('rethrows non-409 failures', async () => {
    vi.stubGlobal(
      'fetch',
      fakeFetch(() => ({ ok: false, status: 500, json: { error: { message: 'boom' } } })),
    );
    await expect(upsertEvent('tok', 'c', 'e', {})).rejects.toThrow('boom');
  });
});

describe('deleteEvent', () => {
  it('treats 404 and 410 as success', async () => {
    for (const status of [404, 410]) {
      vi.stubGlobal('fetch', fakeFetch(() => ({ ok: false, status, json: {} })));
      await expect(deleteEvent('tok', 'c', 'e')).resolves.toBeUndefined();
      vi.unstubAllGlobals();
    }
  });

  it('rethrows other failures', async () => {
    vi.stubGlobal('fetch', fakeFetch(() => ({ ok: false, status: 500, json: { error: { message: 'x' } } })));
    await expect(deleteEvent('tok', 'c', 'e')).rejects.toThrow();
  });
});
