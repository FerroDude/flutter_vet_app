// Firestore (de)serialization helpers shared across the app.
//
// Compatibility rules with the Flutter app:
// - Dates are stored as millisecondsSinceEpoch INTEGERS. We always WRITE numbers.
//   When READING we also accept a Firestore Timestamp ({seconds,nanoseconds}) or
//   an ISO string, matching the tolerant parsing in the Dart models.
// - Enums are stored as integer indices (see enums.ts).

/** Minimal structural shape of a Firestore Timestamp (avoids importing firebase here). */
export interface TimestampLike {
  seconds: number;
  nanoseconds: number;
  toDate?: () => Date;
}

function isTimestampLike(v: unknown): v is TimestampLike {
  return (
    typeof v === 'object' &&
    v !== null &&
    'seconds' in v &&
    'nanoseconds' in v &&
    typeof (v as TimestampLike).seconds === 'number'
  );
}

/** Parse a stored date value (number ms | Timestamp | ISO string) into a Date. */
export function parseDate(value: unknown): Date {
  if (value == null) return new Date();
  if (value instanceof Date) return value;
  if (typeof value === 'number') return new Date(value);
  if (typeof value === 'string') {
    const d = new Date(value);
    return isNaN(d.getTime()) ? new Date() : d;
  }
  if (isTimestampLike(value)) {
    if (typeof value.toDate === 'function') return value.toDate();
    return new Date(value.seconds * 1000 + Math.floor(value.nanoseconds / 1e6));
  }
  return new Date();
}

/** Parse a nullable stored date value. Returns undefined when absent. */
export function parseDateOptional(value: unknown): Date | undefined {
  if (value == null) return undefined;
  return parseDate(value);
}

/** Serialize a Date to the storage format the mobile app expects (ms epoch). */
export function toMillis(date: Date): number {
  return date.getTime();
}

/** Serialize a nullable Date (null preserved for Firestore). */
export function toMillisOptional(date: Date | null | undefined): number | null {
  return date ? date.getTime() : null;
}
