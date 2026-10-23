// Index-stable enums mirroring the Flutter Dart models.
// Stored in Firestore as INTEGER indices. Order MUST match the Dart enums
// exactly so web and mobile stay interoperable.

// lib/models/clinic_models.dart -> enum UserType
export enum UserType {
  petOwner = 0,
  vet = 1,
  clinicAdmin = 2,
  appOwner = 3,
  receptionist = 4,
}

// lib/models/clinic_models.dart -> enum ClinicRole
export enum ClinicRole {
  admin = 0,
  vet = 1,
  receptionist = 2,
}

// lib/models/chat_models.dart -> enum MessageType
export enum MessageType {
  text = 0,
  image = 1,
  video = 2,
  file = 3,
  voice = 4,
  appointment = 5,
  medication = 6,
}

// lib/models/chat_models.dart -> enum MessageStatus
export enum MessageStatus {
  sent = 0,
  delivered = 1,
  read = 2,
}

// lib/models/chat_models.dart -> enum ChatRoomStatus
export enum ChatRoomStatus {
  pending = 0,
  active = 1,
  closed = 2,
}

// lib/models/appointment_request_model.dart -> enum AppointmentRequestStatus
export enum AppointmentRequestStatus {
  pending = 0,
  confirmed = 1,
  denied = 2,
  cancelled = 3,
}

// lib/models/appointment_request_model.dart -> enum TimePreference
export enum TimePreference {
  anyTime = 0,
  morning = 1,
  afternoon = 2,
  evening = 3,
}

// lib/models/medication_model.dart -> enum MedicationStatus
export enum MedicationStatus {
  active = 0,
  paused = 1,
  completed = 2,
  discontinued = 3,
}

// lib/models/medication_model.dart -> enum MedicationFrequency
export enum MedicationFrequency {
  once = 0,
  daily = 1,
  twiceDaily = 2,
  threeTimesDaily = 3,
  weekly = 4,
  asNeeded = 5,
}

// lib/models/event_model.dart -> enum EventType
export enum EventType {
  appointment = 0,
  medication = 1,
  note = 2,
}

// lib/models/symptom_models.dart -> enum SymptomType (stored as STRING keys)
export const SYMPTOM_TYPES = [
  'vomiting',
  'diarrhea',
  'cough',
  'sneezing',
  'choking',
  'seizure',
  'disorientation',
  'circling',
  'restlessness',
  'limping',
  'jointDiscomfort',
  'itching',
  'ocularDischarge',
  'vaginalDischarge',
  'estrus',
  'other',
] as const;

export type SymptomType = (typeof SYMPTOM_TYPES)[number];

export const SYMPTOM_LABELS: Record<SymptomType, string> = {
  vomiting: 'Vómito',
  diarrhea: 'Diarreia',
  cough: 'Tosse',
  sneezing: 'Espirros',
  choking: 'Engasgo',
  seizure: 'Convulsão',
  disorientation: 'Desorientação',
  circling: 'Andar em círculos',
  restlessness: 'Inquietação',
  limping: 'Coxear',
  jointDiscomfort: 'Desconforto articular',
  itching: 'Comichão',
  ocularDischarge: 'Secreção ocular',
  vaginalDischarge: 'Secreção vaginal',
  estrus: 'Cio',
  other: 'Outro',
};

// Sender role strings used on chat messages (senderRole field).
export type SenderRole = 'pet_owner' | 'vet' | 'admin' | 'receptionist';
