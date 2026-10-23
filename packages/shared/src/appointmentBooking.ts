import { EventType } from './enums';

export interface ConfirmAppointmentInput {
  requestId: string;
  clientId: string;
  petId: string;
  petName: string;
  reason: string;
  dateTime: Date;
  vetId: string;
  vetName: string;
  now: Date;
  existingEventId?: string | null;
  existingCreatedAt?: Date | null;
}

/** Fields for the client calendar event a confirm creates or updates. */
export interface BookedAppointment {
  /** Null means create. A second confirm keeps this id. */
  eventId: string | null;
  appointmentRequestId: string;
  userId: string;
  petId: string;
  title: string;
  description: string;
  dateTime: Date;
  type: EventType.appointment;
  vetName: string;
  bookedByVetId: string;
  isConfirmed: true;
  isRecurring: false;
  createdAt: Date;
  updatedAt: Date;
}

export function bookAppointmentFromConfirm(input: ConfirmAppointmentInput): BookedAppointment {
  const pet = input.petName.trim();
  const existingId = input.existingEventId ?? null;
  return {
    eventId: existingId,
    appointmentRequestId: input.requestId,
    userId: input.clientId,
    petId: input.petId,
    title: pet ? `Consulta — ${pet}` : 'Consulta',
    description: input.reason.trim(),
    dateTime: input.dateTime,
    type: EventType.appointment,
    vetName: input.vetName,
    bookedByVetId: input.vetId,
    isConfirmed: true,
    isRecurring: false,
    createdAt: existingId ? (input.existingCreatedAt ?? input.now) : input.now,
    updatedAt: input.now,
  };
}
