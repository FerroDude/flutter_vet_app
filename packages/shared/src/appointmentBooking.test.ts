import { describe, expect, it } from 'vitest';
import { UserType, ClinicRole, EventType } from './enums';
import { isPetOwner, isVet } from './types';
import { userProfileFromFirestore, userProfileToFirestore } from './serializers';
import { bookAppointmentFromConfirm } from './appointmentBooking';

describe('isVet', () => {
  it('treats a solo vet as a vet without a clinic role', () => {
    const profile = { userType: UserType.vet, clinicRole: null };
    expect(isVet(profile)).toBe(true);
    expect(isPetOwner({ ...profile, globalType: null })).toBe(false);
  });

  it('still treats a clinic-role vet as a vet', () => {
    expect(isVet({ userType: UserType.petOwner, clinicRole: ClinicRole.vet })).toBe(true);
  });

  it('does not treat a client as a vet', () => {
    expect(isVet({ userType: UserType.petOwner, clinicRole: null })).toBe(false);
  });
});

describe('user profile vetId', () => {
  it('round-trips vetId', () => {
    const stored = userProfileToFirestore(
      userProfileFromFirestore('client', {
        email: 'a@b.c',
        displayName: 'Ana',
        userType: UserType.petOwner,
        vetId: 'vet-1',
        hasSkippedClinicSelection: true,
        mustChangePassword: false,
        createdAt: 1,
        updatedAt: 2,
        isActive: true,
      }),
    );
    expect(stored.vetId).toBe('vet-1');
  });
});

describe('bookAppointmentFromConfirm', () => {
  const when = new Date('2026-10-20T09:30:00.000Z');
  const now = new Date('2026-10-17T18:00:00.000Z');

  const base = {
    requestId: 'req-1',
    clientId: 'client-1',
    petId: 'pet-1',
    petName: 'Luna',
    reason: 'Vacina',
    dateTime: when,
    vetId: 'vet-1',
    vetName: 'Dra. Silva',
    now,
  };

  it('creates one event on the first confirm', () => {
    const booked = bookAppointmentFromConfirm(base);
    expect(booked.eventId).toBeNull();
    expect(booked.appointmentRequestId).toBe('req-1');
    expect(booked.userId).toBe('client-1');
    expect(booked.dateTime).toBe(when);
    expect(booked.type).toBe(EventType.appointment);
    expect(booked.title).toBe('Consulta — Luna');
    expect(booked.bookedByVetId).toBe('vet-1');
    expect(booked.isConfirmed).toBe(true);
    expect(booked.createdAt).toBe(now);
    expect(booked.updatedAt).toBe(now);
  });

  it('updates the same event on a second confirm', () => {
    const created = new Date('2026-10-18T10:00:00.000Z');
    const later = new Date('2026-10-21T15:00:00.000Z');
    const booked = bookAppointmentFromConfirm({
      ...base,
      dateTime: later,
      now: new Date('2026-10-19T12:00:00.000Z'),
      existingEventId: 'event-9',
      existingCreatedAt: created,
    });
    expect(booked.eventId).toBe('event-9');
    expect(booked.createdAt).toBe(created);
    expect(booked.dateTime).toBe(later);
    expect(booked.updatedAt).toEqual(new Date('2026-10-19T12:00:00.000Z'));
  });

  it('titles a nameless pet as Consulta', () => {
    expect(bookAppointmentFromConfirm({ ...base, petName: '  ' }).title).toBe('Consulta');
  });
});
