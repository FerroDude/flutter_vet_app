// "Add to calendar" helpers: a Google Calendar template link for gmail
// addresses and a downloadable .ics file for everyone else.

export interface CalendarItem {
  id: string;
  title: string;
  start: Date;
  end?: Date;
  details?: string;
  location?: string;
}

const DEFAULT_DURATION_MS = 30 * 60 * 1000;

const pad = (n: number) => `${n}`.padStart(2, '0');

/** YYYYMMDDTHHMMSSZ in UTC — the format Google and ICS both take. */
export function utcStamp(d: Date): string {
  return (
    `${d.getUTCFullYear()}${pad(d.getUTCMonth() + 1)}${pad(d.getUTCDate())}` +
    `T${pad(d.getUTCHours())}${pad(d.getUTCMinutes())}${pad(d.getUTCSeconds())}Z`
  );
}

export function isGmail(email?: string | null): boolean {
  if (!email) return false;
  return /^[^@\s]+@(gmail|googlemail)\.com$/i.test(email.trim());
}

export function googleCalendarUrl(item: CalendarItem): string {
  const end = item.end ?? new Date(item.start.getTime() + DEFAULT_DURATION_MS);
  const params = new URLSearchParams({
    action: 'TEMPLATE',
    text: item.title,
    dates: `${utcStamp(item.start)}/${utcStamp(end)}`,
  });
  if (item.details) params.set('details', item.details);
  if (item.location) params.set('location', item.location);
  return `https://calendar.google.com/calendar/render?${params.toString()}`;
}

function icsEscape(s: string): string {
  return s
    .replace(/\\/g, '\\\\')
    .replace(/;/g, '\\;')
    .replace(/,/g, '\\,')
    .replace(/\r?\n/g, '\\n');
}

export function icsContent(item: CalendarItem, now = new Date()): string {
  const end = item.end ?? new Date(item.start.getTime() + DEFAULT_DURATION_MS);
  const lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Yoshi Vet Care//PT',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'BEGIN:VEVENT',
    `UID:${item.id}@yoshivetcare`,
    `DTSTAMP:${utcStamp(now)}`,
    `DTSTART:${utcStamp(item.start)}`,
    `DTEND:${utcStamp(end)}`,
    `SUMMARY:${icsEscape(item.title)}`,
  ];
  if (item.details) lines.push(`DESCRIPTION:${icsEscape(item.details)}`);
  if (item.location) lines.push(`LOCATION:${icsEscape(item.location)}`);
  lines.push('END:VEVENT', 'END:VCALENDAR');
  return lines.join('\r\n');
}

export function downloadIcs(filename: string, content: string): void {
  const blob = new Blob([content], { type: 'text/calendar;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}
