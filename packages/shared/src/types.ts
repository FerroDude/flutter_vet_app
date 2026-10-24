// TypeScript mirrors of the Flutter domain models. These are the in-memory
// (parsed) shapes used by the web app. Firestore <-> these are handled by
// per-feature converters that use helpers in converters.ts.

import { ClinicRole, UserType } from './enums';
import type {
  MessageType,
  MessageStatus,
  ChatRoomStatus,
  AppointmentRequestStatus,
  TimePreference,
  MedicationStatus,
  MedicationFrequency,
  EventType,
  SymptomType,
  SenderRole,
} from './enums';

export interface UserProfile {
  id: string;
  email: string;
  displayName: string;
  userType: UserType;
  connectedClinicId?: string | null;
  /** Solo-practice vet this client belongs to. One client, one vet. */
  vetId?: string | null;
  clinicRole?: ClinicRole | null;
  phone?: string | null;
  address?: string | null;
  postalCode?: string | null;
  hasSkippedClinicSelection: boolean;
  mustChangePassword: boolean;
  createdAt: Date;
  updatedAt: Date;
  isActive: boolean;
  globalType?: string | null; // 'appOwner' | null
  fcmToken?: string | null;
}

export interface Pet {
  id: string;
  ownerId: string;
  name: string;
  species?: string | null;
  breed?: string | null;
  sex?: string | null;
  birthDate?: Date | null;
  weightKg?: number | null;
  microchip?: string | null;
  photoUrl?: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface PetSymptom {
  id: string;
  ownerId: string;
  petId: string;
  type: SymptomType;
  timestamp: Date;
  note?: string | null;
  createdAt: Date;
}

export interface DoseLog {
  id: string;
  scheduledTime: Date;
  takenAt?: Date | null;
  skipped: boolean;
  notes?: string | null;
}

export interface TimeOfDay {
  hour: number;
  minute: number;
}

export interface Medication {
  id: string;
  petId: string;
  ownerId: string;
  name: string;
  dosage: string;
  instructions?: string | null;
  frequency: MedicationFrequency;
  doseTimes: TimeOfDay[];
  startDate: Date;
  endDate?: Date | null;
  totalDays?: number | null;
  status: MedicationStatus;
  trackDoses: boolean;
  doseHistory: DoseLog[];
  remindersEnabled: boolean;
  createdAt: Date;
  updatedAt: Date;
  prescribedByVetId?: string | null;
  prescribedByVetName?: string | null;
}

export interface ChatMessage {
  id: string;
  chatId: string;
  senderId: string;
  senderName: string;
  senderRole: SenderRole | string;
  content: string;
  type: MessageType;
  status: MessageStatus;
  timestamp: Date;
  deliveredAt?: Date | null;
  readAt?: Date | null;
  mediaUrl?: string | null;
  thumbnailUrl?: string | null;
  fileName?: string | null;
  fileSize?: number | null;
  mimeType?: string | null;
  audioDuration?: number | null;
  appointmentId?: string | null;
  medicationId?: string | null;
  metadata?: Record<string, unknown> | null;
  isDeleted: boolean;
  deletedAt?: Date | null;
}

export interface ChatRoom {
  id: string;
  /** Legacy clinic key. New rooms are addressed by vetId. */
  clinicId?: string | null;
  petOwnerId: string;
  petOwnerName: string;
  vetId: string;
  vetName: string;
  petIds: string[];
  lastMessage?: ChatMessage | null;
  unreadCounts: Record<string, number>;
  createdAt: Date;
  updatedAt: Date;
  isActive: boolean;
  topic?: string | null;
  status: ChatRoomStatus;
  requestDescription?: string | null;
  initiatedBy?: string | null;
  staffRole?: string | null;
}

export interface AppointmentRequest {
  id: string;
  /** Vet who receives this request. New writes use this, not clinicId. */
  vetId: string;
  /** Legacy clinic key. Old documents may still have it. New writes omit it. */
  clinicId?: string | null;
  petOwnerId: string;
  petOwnerName: string;
  petId: string;
  petName: string;
  petSpecies?: string | null;
  preferredDateStart: Date;
  preferredDateEnd: Date;
  timePreference: TimePreference;
  reason: string;
  notes?: string | null;
  status: AppointmentRequestStatus;
  handledBy?: string | null;
  handledByName?: string | null;
  handledAt?: Date | null;
  responseMessage?: string | null;
  linkedChatRoomId?: string | null;
  /** Client calendar event written when the vet confirms. */
  calendarEventId?: string | null;
  /** Concrete time the vet booked. */
  bookedDateTime?: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface CalendarEventBase {
  id: string;
  title: string;
  description: string;
  dateTime: Date;
  type: EventType;
  petId?: string | null;
  userId: string;
  seriesId?: string | null;
  isRecurring: boolean;
  recurrencePattern?: string | null; // daily | weekly | monthly
  recurrenceInterval?: number | null;
  endDate?: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

// Roles: the app only has vets and their clients (pet owners).
export function isVet(u: Pick<UserProfile, 'clinicRole' | 'userType'>): boolean {
  return u.userType === UserType.vet || u.clinicRole === ClinicRole.vet;
}
export function isPetOwner(u: Pick<UserProfile, 'clinicRole' | 'userType'>): boolean {
  return u.userType === UserType.petOwner && !isVet(u);
}
