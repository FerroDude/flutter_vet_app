import { CalendarPlus, Download } from 'lucide-react';
import { useAuth } from '@/auth/AuthProvider';
import {
  downloadIcs,
  googleCalendarUrl,
  icsContent,
  isGmail,
  type CalendarItem,
} from '@/lib/calendarLinks';
import { Menu, type MenuItem } from '@/components/ui/Menu';
import { t } from '@/i18n';

const pad = (n: number) => `${n}`.padStart(2, '0');

function filename(start: Date): string {
  return `consulta-${start.getFullYear()}-${pad(start.getMonth() + 1)}-${pad(start.getDate())}.ics`;
}

/**
 * "Add to calendar" menu: Google Calendar for gmail users, a .ics download
 * for everyone. Trigger is a CalendarPlus icon button.
 */
export function AddToCalendar({ item }: { item: CalendarItem }) {
  const { profile, firebaseUser } = useAuth();
  const email = profile?.email || firebaseUser?.email;

  const items: MenuItem[] = [];
  if (isGmail(email)) {
    items.push({
      label: 'Google Calendar',
      icon: <CalendarPlus size={15} />,
      onClick: () => window.open(googleCalendarUrl(item), '_blank', 'noopener'),
    });
  }
  items.push({
    label: t('cal.ics'),
    icon: <Download size={15} />,
    onClick: () => downloadIcs(filename(item.start), icsContent(item)),
  });

  return <Menu label={t('cal.add')} trigger={<CalendarPlus size={15} />} items={items} />;
}
