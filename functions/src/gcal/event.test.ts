import { describe, expect, it } from 'vitest';
import { buildGoogleEvent, googleEventId, syncHash, toMs } from './event.js';

const base = {
  title: 'Consulta — Luna',
  description: 'Revisão anual',
  dateTime: Date.UTC(2026, 5, 10, 14, 30, 0),
  location: 'Domicílio',
  clientName: 'Ana',
  petName: 'Luna',
  vetName: 'Dra. Silva',
  cancelledAt: null,
  cancelReason: null,
  bookedByVetId: 'vet',
};

const ids = { clientId: 'client', eventId: 'ev1', appUrl: 'https://app/agenda' };

describe('googleEventId', () => {
  it('is deterministic, 40 hex chars', () => {
    const id = googleEventId('client', 'ev1');
    expect(id).toMatch(/^[0-9a-f]{40}$/);
    expect(googleEventId('client', 'ev1')).toBe(id);
    expect(googleEventId('client', 'ev2')).not.toBe(id);
    expect(googleEventId('other', 'ev1')).not.toBe(id);
  });
});

describe('syncHash', () => {
  it('ignores non-synced fields (gcal, updatedAt)', () => {
    const a = syncHash(base);
    const withGcal = syncHash({
      ...base,
      gcal: { eventId: 'x', status: 'synced', hash: 'h', error: null },
      updatedAt: 123,
    });
    expect(withGcal).toBe(a);
  });

  it('changes when a synced field changes', () => {
    expect(syncHash({ ...base, title: 'Outro' })).not.toBe(syncHash(base));
    expect(syncHash({ ...base, cancelledAt: 1 })).not.toBe(syncHash(base));
    expect(syncHash({ ...base, dateTime: base.dateTime + 1000 })).not.toBe(syncHash(base));
  });
});

describe('toMs', () => {
  it('handles ms, Date and Timestamp-like values', () => {
    expect(toMs(1000)).toBe(1000);
    expect(toMs(new Date(2000))).toBe(2000);
    expect(toMs({ toMillis: () => 3000 })).toBe(3000);
    expect(toMs({ _seconds: 4, _nanoseconds: 500000000 })).toBe(4500);
    expect(toMs(null)).toBeNull();
  });
});

describe('buildGoogleEvent', () => {
  it('builds a normal event with 30-min end and extended properties', () => {
    const ev = buildGoogleEvent(base, ids);
    expect(ev.status).toBe('confirmed');
    expect(ev.summary).toBe('Consulta — Luna · Ana');
    expect(buildGoogleEvent({ ...base, title: 'Vacina' }, ids).summary).toBe('Vacina · Ana (Luna)');
    expect(ev.start).toEqual({
      dateTime: '2026-06-10T14:30:00.000Z',
      timeZone: 'Europe/Lisbon',
    });
    expect(new Date(ev.end.dateTime).getTime() - new Date(ev.start.dateTime).getTime()).toBe(
      30 * 60 * 1000,
    );
    expect(ev.location).toBe('Domicílio');
    expect(ev.description).toContain('Revisão anual');
    expect(ev.description).toContain('https://app/agenda');
    expect(ev.extendedProperties.private).toEqual({
      vetplusClientId: 'client',
      vetplusEventId: 'ev1',
    });
    expect(ev.colorId).toBeUndefined();
  });

  it('prefixes cancelled events, sets colorId 8 and adds the reason', () => {
    const ev = buildGoogleEvent(
      { ...base, cancelledAt: base.dateTime - 1000, cancelReason: 'Doente' },
      ids,
    );
    expect(ev.summary.startsWith('CANCELADA · ')).toBe(true);
    expect(ev.colorId).toBe('8');
    expect(ev.description).toContain('Motivo do cancelamento: Doente');
  });

  it('accepts Timestamp-like dateTime', () => {
    const ev = buildGoogleEvent(
      { ...base, dateTime: { toMillis: () => base.dateTime } },
      ids,
    );
    expect(ev.start.dateTime).toBe('2026-06-10T14:30:00.000Z');
  });
});
