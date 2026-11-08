import { describe, expect, it } from 'vitest';
import { EventType } from '@vetplus/shared';
import { diffVetBookings } from './vetBookings';
import type { AppointmentEvent, CalendarEvent } from './eventService';

const NOW = Date.UTC(2025, 5, 10, 12, 0, 0);
const FUTURE = new Date(NOW + 86_400_000);
const PAST = new Date(NOW - 86_400_000);

function appt(id: string, over: Partial<AppointmentEvent> = {}): AppointmentEvent {
  return {
    id,
    title: 'Consulta',
    description: '',
    dateTime: FUTURE,
    type: EventType.appointment,
    userId: 'client',
    isRecurring: false,
    createdAt: new Date(),
    updatedAt: new Date(),
    isConfirmed: true,
    bookedByVetId: 'vet',
    petName: 'Luna',
    vetName: 'Dra. Silva',
    ...over,
  } as AppointmentEvent;
}

describe('diffVetBookings', () => {
  it('flags a new vet-booked future appointment as booked and tracks it', () => {
    const { booked, rescheduled, next } = diffVetBookings(new Map(), [appt('a1')], NOW);
    expect(booked.map((e) => e.id)).toEqual(['a1']);
    expect(rescheduled).toEqual([]);
    expect(next.get('a1')).toBe(FUTURE.getTime());
  });

  it('tracks a request-confirmed appointment without flagging it', () => {
    const { booked, next } = diffVetBookings(
      new Map(),
      [appt('a2', { appointmentRequestId: 'r1' })],
      NOW,
    );
    expect(booked).toEqual([]);
    expect(next.get('a2')).toBe(FUTURE.getTime());
  });

  it('tracks a new past appointment without flagging it', () => {
    const { booked, next } = diffVetBookings(new Map(), [appt('a3', { dateTime: PAST })], NOW);
    expect(booked).toEqual([]);
    expect(next.get('a3')).toBe(PAST.getTime());
  });

  it('flags a changed dateTime as rescheduled, unchanged as nothing', () => {
    const prev = new Map([
      ['a1', NOW + 86_400_000],
      ['a2', FUTURE.getTime()],
    ]);
    const moved = appt('a1', { dateTime: new Date(FUTURE.getTime() + 3_600_000) });
    const same = appt('a2');
    const { booked, rescheduled, next } = diffVetBookings(prev, [moved, same], NOW);
    expect(booked).toEqual([]);
    expect(rescheduled.map((e) => e.id)).toEqual(['a1']);
    expect(next.get('a1')).toBe(moved.dateTime.getTime());
  });

  it('ignores cancelled and non-vet events', () => {
    const cancelled = appt('a4', { cancelledAt: new Date(), cancelledBy: 'client', cancelReason: 'x' });
    const own = appt('a5', { bookedByVetId: null });
    const med = { ...appt('a6'), type: EventType.medication } as unknown as CalendarEvent;
    const { booked, rescheduled, next } = diffVetBookings(new Map(), [cancelled, own, med], NOW);
    expect(booked).toEqual([]);
    expect(rescheduled).toEqual([]);
    expect(next.size).toBe(0);
  });

  it('reschedules request-based appointments too', () => {
    const prev = new Map([['a7', NOW + 86_400_000]]);
    const moved = appt('a7', {
      appointmentRequestId: 'r1',
      dateTime: new Date(FUTURE.getTime() + 7_200_000),
    });
    const { rescheduled } = diffVetBookings(prev, [moved], NOW);
    expect(rescheduled.map((e) => e.id)).toEqual(['a7']);
  });
});
