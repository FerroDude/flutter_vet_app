import { Routes, Route, Navigate } from 'react-router-dom';
import {
  LayoutDashboard,
  PawPrint,
  CalendarDays,
  CalendarClock,
  MessageCircle,
  User,
} from 'lucide-react';
import { useAuth } from '@/auth/AuthProvider';
import { AppLayout, type NavItem } from './AppLayout';
import { PetOwnerDashboard } from '@/features/dashboard/PetOwnerDashboard';
import { PetsPage } from '@/features/pets/PetsPage';
import { PetForm } from '@/features/pets/PetForm';
import { PetDetailPage } from '@/features/pets/PetDetailPage';
import { CalendarPage } from '@/features/calendar/CalendarPage';
import { AppointmentsPage } from '@/features/appointments/AppointmentsPage';
import { ChatPage } from '@/features/chat/ChatPage';
import { ProfileSettingsPage } from '@/features/profile/ProfileSettingsPage';
import { IncomingMessageToast } from '@/features/chat/IncomingMessageToast';

const NAV: NavItem[] = [
  { to: '/', label: 'Painel', icon: LayoutDashboard, end: true },
  { to: '/pets', label: 'Animais', icon: PawPrint },
  { to: '/calendar', label: 'Calendário', icon: CalendarDays },
  { to: '/appointments', label: 'Marcações', icon: CalendarClock },
  { to: '/chat', label: 'Chat', icon: MessageCircle },
  { to: '/profile', label: 'Perfil', icon: User },
];

export function PetOwnerApp() {
  const { profile, signOutUser } = useAuth();

  return (
    <AppLayout
      nav={NAV}
      userName={profile?.displayName?.trim() || profile?.email || 'Cliente'}
      userSubtitle="Cliente"
      onSignOut={() => void signOutUser()}
    >
      <IncomingMessageToast />
      <Routes>
        <Route index element={<PetOwnerDashboard />} />
        <Route path="pets" element={<PetsPage />} />
        <Route path="pets/new" element={<PetForm />} />
        <Route path="pets/:petId" element={<PetDetailPage />} />
        <Route path="pets/:petId/edit" element={<PetForm />} />
        <Route path="calendar" element={<CalendarPage />} />
        <Route path="appointments" element={<AppointmentsPage />} />
        <Route path="chat" element={<ChatPage />} />
        <Route path="clinic" element={<Navigate to="/chat" replace />} />
        <Route path="profile" element={<ProfileSettingsPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AppLayout>
  );
}
