// Diff of vet-booked appointments between snapshots, for VetBookedToast.
// Tracked by id -> dateTime ms; cancelled or non-vet events never count.

import { EventType } from '@vetplus/shared';
import type { AppointmentEvent, CalendarEvent } from './eventService';

export interface BookingDiff {
  /** New vet-booked future appointments not tied to a request. */
  booked: AppointmentEvent[];
  /** Already-known appointments whose dateTime moved. */
  rescheduled: AppointmentEvent[];
  next: Map<string, number>;
}

function trackable(e: CalendarEvent): e is AppointmentEvent {
  return e.type === EventType.appointment && Boolean(e.bookedByVetId) && !e.cancelledAt;
}

export function diffVetBookings(
  prev: Map<string, number>,
  events: CalendarEvent[],
  now: number,
): BookingDiff {
  const next = new Map(prev);
  const booked: AppointmentEvent[] = [];
  const rescheduled: AppointmentEvent[] = [];
  for (const e of events) {
    if (!trackable(e)) continue;
    const ms = e.dateTime.getTime();
    const old = prev.get(e.id);
    if (old === undefined) {
      next.set(e.id, ms);
      // Confirmed requests already alert via ConfirmedRequestToast.
      if (!e.appointmentRequestId && ms > now) booked.push(e);
    } else if (old !== ms) {
      next.set(e.id, ms);
      rescheduled.push(e);
    }
  }
  return { booked, rescheduled, next };
}
