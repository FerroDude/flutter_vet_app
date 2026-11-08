import { describe, expect, it } from 'vitest';
import { googleCalendarUrl, icsContent, isGmail, utcStamp, type CalendarItem } from './calendarLinks';

const item: CalendarItem = {
  id: 'abc123',
  title: 'Consulta — Luna',
  start: new Date(Date.UTC(2025, 5, 10, 14, 30, 0)),
};

describe('utcStamp', () => {
  it('formats UTC as YYYYMMDDTHHMMSSZ', () => {
    expect(utcStamp(new Date(Date.UTC(2025, 0, 5, 9, 5, 3)))).toBe('20250105T090503Z');
  });
});

describe('isGmail', () => {
  it('matches gmail and googlemail, case-insensitive and trimmed', () => {
    expect(isGmail('a@gmail.com')).toBe(true);
    expect(isGmail(' A@GMAIL.COM ')).toBe(true);
    expect(isGmail('b@googlemail.com')).toBe(true);
    expect(isGmail('c@gmail.com.evil.org')).toBe(false);
    expect(isGmail('d@outlook.com')).toBe(false);
    expect(isGmail('')).toBe(false);
    expect(isGmail(null)).toBe(false);
    expect(isGmail(undefined)).toBe(false);
  });
});

describe('googleCalendarUrl', () => {
  it('builds a TEMPLATE url with title and UTC dates', () => {
    const url = googleCalendarUrl(item);
    expect(url.startsWith('https://calendar.google.com/calendar/render?')).toBe(true);
    const params = new URLSearchParams(url.split('?')[1]);
    expect(params.get('action')).toBe('TEMPLATE');
    expect(params.get('text')).toBe('Consulta — Luna');
    expect(params.get('dates')).toBe('20250610T143000Z/20250610T150000Z'); // default +30min
    expect(params.get('details')).toBeNull();
    expect(params.get('location')).toBeNull();
  });

  it('uses the explicit end and includes details/location when set', () => {
    const url = googleCalendarUrl({
      ...item,
      end: new Date(Date.UTC(2025, 5, 10, 16, 0, 0)),
      details: 'Trazer cartão',
      location: 'Clínica',
    });
    const params = new URLSearchParams(url.split('?')[1]);
    expect(params.get('dates')).toBe('20250610T143000Z/20250610T160000Z');
    expect(params.get('details')).toBe('Trazer cartão');
    expect(params.get('location')).toBe('Clínica');
  });
});

describe('icsContent', () => {
  const now = new Date(Date.UTC(2025, 5, 1, 12, 0, 0));

  it('emits a VCALENDAR with one VEVENT and CRLF endings', () => {
    const ics = icsContent(item, now);
    expect(ics).toContain('\r\n');
    expect(ics.replace(/\r\n/g, '')).not.toContain('\n');
    expect(ics).toContain('VERSION:2.0');
    expect(ics).toContain('PRODID:-//Yoshi Vet Care//PT');
    expect(ics).toContain('CALSCALE:GREGORIAN');
    expect(ics).toContain('METHOD:PUBLISH');
    expect(ics).toContain('UID:abc123@yoshivetcare');
    expect(ics).toContain('DTSTAMP:20250601T120000Z');
    expect(ics).toContain('DTSTART:20250610T143000Z');
    expect(ics).toContain('DTEND:20250610T150000Z');
    expect(ics).toContain('SUMMARY:Consulta — Luna');
    expect(ics).not.toContain('DESCRIPTION:');
    expect(ics).not.toContain('LOCATION:');
    expect(ics.endsWith('END:VCALENDAR')).toBe(true);
  });

  it('escapes commas, semicolons, backslashes and newlines', () => {
    const ics = icsContent(
      { ...item, title: 'a,b;c\\d', details: 'linha1\nlinha2', location: 'Rua A, 1' },
      now,
    );
    expect(ics).toContain('SUMMARY:a\\,b\\;c\\\\d');
    expect(ics).toContain('DESCRIPTION:linha1\\nlinha2');
    expect(ics).toContain('LOCATION:Rua A\\, 1');
  });
});
