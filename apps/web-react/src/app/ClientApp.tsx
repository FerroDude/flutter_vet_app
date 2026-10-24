import { Routes, Route, Navigate } from 'react-router-dom';
import { LayoutDashboard, PawPrint, CalendarDays, MessageCircle, User } from 'lucide-react';
import { useAuth } from '@/auth/AuthProvider';
import { useRooms } from '@/lib/chatService';
import { AppLayout, type NavItem } from './AppLayout';
import { ClientDashboard } from '@/features/dashboard/ClientDashboard';
import { PetsPage } from '@/features/pets/PetsPage';
import { PetForm } from '@/features/pets/PetForm';
import { PetDetailPage } from '@/features/pets/PetDetailPage';
import { AgendaPage } from '@/features/calendar/AgendaPage';
import { AppointmentPage } from '@/features/calendar/AppointmentPage';
import { ChatPage } from '@/features/chat/ChatPage';
import { ProfileSettingsPage } from '@/features/profile/ProfileSettingsPage';
import { IncomingMessageToast } from '@/features/chat/IncomingMessageToast';
import { ConfirmedRequestToast } from '@/features/calendar/ConfirmedRequestToast';

export function ClientApp() {
  const { firebaseUser, profile, signOutUser } = useAuth();
  const { unread } = useRooms('petOwnerId', firebaseUser?.uid ?? '');

  const nav: NavItem[] = [
    { to: '/', label: 'Painel', icon: LayoutDashboard, end: true },
    { to: '/pets', label: 'Animais', icon: PawPrint },
    { to: '/agenda', label: 'Agenda', icon: CalendarDays },
    { to: '/chat', label: 'Chat', icon: MessageCircle, badge: unread },
    { to: '/profile', label: 'Perfil', icon: User },
  ];

  return (
    <AppLayout
      nav={nav}
      userName={profile?.displayName?.trim() || profile?.email || 'Cliente'}
      userSubtitle="Cliente"
      onSignOut={() => void signOutUser()}
    >
      <IncomingMessageToast />
      <ConfirmedRequestToast />
      <Routes>
        <Route index element={<ClientDashboard />} />
        <Route path="pets" element={<PetsPage />} />
        <Route path="pets/new" element={<PetForm />} />
        <Route path="pets/:petId" element={<PetDetailPage />} />
        <Route path="pets/:petId/edit" element={<PetForm />} />
        <Route path="agenda" element={<AgendaPage />} />
        <Route path="agenda/consultas/:eventId" element={<AppointmentPage />} />
        <Route path="chat" element={<ChatPage />} />
        <Route path="profile" element={<ProfileSettingsPage />} />
        {/* Old links */}
        <Route path="calendar" element={<Navigate to="/agenda" replace />} />
        <Route path="appointments" element={<Navigate to="/agenda" replace />} />
        <Route path="clinic" element={<Navigate to="/chat" replace />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AppLayout>
  );
}
