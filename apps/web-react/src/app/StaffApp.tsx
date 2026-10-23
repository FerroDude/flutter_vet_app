import { Routes, Route, Navigate } from 'react-router-dom';
import {
  LayoutDashboard,
  CalendarClock,
  CalendarDays,
  MessageCircle,
  Users,
  User,
} from 'lucide-react';
import { useAuth } from '@/auth/AuthProvider';
import { AppLayout, type NavItem } from './AppLayout';
import { StaffDashboard } from '@/features/staff/StaffDashboard';
import { AppointmentQueuePage } from '@/features/staff/AppointmentQueuePage';
import { VetAgendaPage } from '@/features/staff/VetAgendaPage';
import { StaffChatPage } from '@/features/staff/StaffChatPage';
import { PatientsPage } from '@/features/staff/PatientsPage';
import { PatientDetailPage } from '@/features/staff/PatientDetailPage';
import { ProfileSettingsPage } from '@/features/profile/ProfileSettingsPage';
import { PetForm } from '@/features/pets/PetForm';
import { PetDetailPage } from '@/features/pets/PetDetailPage';
import { IncomingMessageToast } from '@/features/chat/IncomingMessageToast';

const NAV: NavItem[] = [
  { to: '/', label: 'Painel', icon: LayoutDashboard, end: true },
  { to: '/agenda', label: 'Agenda', icon: CalendarDays },
  { to: '/patients', label: 'Clientes', icon: Users },
  { to: '/requests', label: 'Pedidos', icon: CalendarClock },
  { to: '/chat', label: 'Chat', icon: MessageCircle },
  { to: '/profile', label: 'Perfil', icon: User },
];

export function StaffApp() {
  const { profile, signOutUser } = useAuth();

  return (
    <AppLayout
      nav={NAV}
      userName={profile?.displayName?.trim() || profile?.email || 'Veterinária'}
      userSubtitle="Veterinária"
      onSignOut={() => void signOutUser()}
    >
      <IncomingMessageToast />
      <Routes>
        <Route index element={<StaffDashboard showRequests />} />
        <Route path="agenda" element={<VetAgendaPage />} />
        <Route path="requests" element={<AppointmentQueuePage />} />
        <Route path="patients" element={<PatientsPage />} />
        <Route path="patients/:ownerId/pets/new" element={<PetForm />} />
        <Route path="patients/:ownerId/pets/:petId/edit" element={<PetForm />} />
        <Route path="patients/:ownerId/pets/:petId" element={<PetDetailPage />} />
        <Route path="patients/:ownerId" element={<PatientDetailPage />} />
        <Route path="chat" element={<StaffChatPage />} />
        <Route path="profile" element={<ProfileSettingsPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AppLayout>
  );
}
