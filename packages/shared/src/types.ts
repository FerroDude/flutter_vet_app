// TypeScript mirrors of the Flutter domain models. These are the in-memory
// (parsed) shapes used by the web app. Firestore <-> these are handled by
// per-feature converters that use helpers in converters.ts.

import { ClinicRole, UserType } from './enums';

/* ----------------------------- Clinics (VetTempo) --------------------------- */

/** Role of a staff member inside one clinic. String union — NOT the legacy
 *  numeric ClinicRole enum on UserProfile. An owner is also a vet. */
export type ClinicMemberRole = 'owner' | 'vet';

export interface ClinicBrand {
  primary: string;
  accent?: string | null;
  logoWideUrl?: string | null;
  logoMarkUrl?: string | null;
}

export interface ClinicContact {
  phone?: string | null;
  address?: string | null;
  postalCode?: string | null;
}

export interface Clinic {
  id: string;
  name: string;
  isActive: boolean;
  brand: ClinicBrand;
  contact: ClinicContact;
  createdAt: Date;
  updatedAt: Date;
}

/** clinics/{c}/members/{uid} — server-written only. */
export interface ClinicMember {
  role: ClinicMemberRole;
  displayName: string;
  email: string;
  active: boolean;
  joinedAt: Date;
}

export type ClinicClientLinkStatus = 'pending' | 'active' | 'declined' | 'left';

/** clinics/{c}/clients/{uid} — the link between a client and a clinic.
 *  'pending' links share nothing until the client accepts. */
export interface ClinicClientLink {
  clientId: string;
  clientName: string;
  clinicName: string;
  status: ClinicClientLinkStatus;
  addedBy: string;
  addedByName: string;
  addedAt: Date;
  respondedAt?: Date | null;
}

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
  phone2?: string | null;
  address?: string | null;
  postalCode?: string | null;
  country?: string | null;
  nif?: string | null;
  hasSkippedClinicSelection: boolean;
  mustChangePassword: boolean;
  createdAt: Date;
  updatedAt: Date;
  isActive: boolean;
  globalType?: string | null; // 'appOwner' | null
  fcmToken?: string | null;
  /** Client created without the invite email yet. Legacy docs: treated as false. */
  invitePending?: boolean;
  /** When the invite (set-password email) was last sent. */
  invitedAt?: Date | null;
  /** Server-only: clinic ids where this staff user is an active member. */
  memberOf?: string[];
  /** Server-only: clinic ids where this client has an ACTIVE link. */
  clientOf?: string[];
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
  /** Clinic this room belongs to. */
  clinicId?: string | null;
  petOwnerId: string;
  petOwnerName: string;
  /** Assigned vet. null = the room sits in the clinic's pool ("any vet"). */
  vetId: string | null;
  vetName: string | null;
  /** Vet the client asked for; null = "any vet" (pool). */
  requestedVetId?: string | null;
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
  /** Assigned vet. null = pooled for the whole clinic ("any vet"). */
  vetId: string | null;
  /** Clinic this request belongs to. */
  clinicId?: string | null;
  /** Vet the client asked for; null = "any vet" (pool). */
  requestedVetId?: string | null;
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
