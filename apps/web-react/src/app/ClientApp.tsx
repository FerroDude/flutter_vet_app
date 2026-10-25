import { Routes, Route, Navigate } from 'react-router-dom';
import { LayoutDashboard, PawPrint, CalendarDays, MessageCircle, User } from 'lucide-react';
import { useAuth } from '@/auth/AuthProvider';
import { useRooms } from '@/lib/chatService';
import { AppLayout, type NavItem } from './AppLayout';
import { t } from '@/i18n';
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
import { FoundReportToast } from '@/features/pets/FoundReportToast';

export function ClientApp() {
  const { firebaseUser, profile, signOutUser } = useAuth();
  const { unread } = useRooms('petOwnerId', firebaseUser?.uid ?? '');

  const nav: NavItem[] = [
    { to: '/', label: t('nav.dashboard'), icon: LayoutDashboard, end: true },
    { to: '/pets', label: t('nav.pets'), icon: PawPrint },
    { to: '/agenda', label: t('nav.agenda'), icon: CalendarDays },
    { to: '/chat', label: t('nav.chat'), icon: MessageCircle, badge: unread },
    { to: '/profile', label: t('nav.profile'), icon: User },
  ];

  return (
    <AppLayout
      nav={nav}
      userName={profile?.displayName?.trim() || profile?.email || t('common.client')}
      userSubtitle={t('common.client')}
      onSignOut={() => void signOutUser()}
    >
      <IncomingMessageToast />
      <ConfirmedRequestToast />
      <FoundReportToast />
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
