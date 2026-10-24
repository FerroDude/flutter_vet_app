import { Routes, Route, Navigate } from 'react-router-dom';
import { LayoutDashboard, CalendarDays, MessageCircle, Users, User } from 'lucide-react';
import { useAuth } from '@/auth/AuthProvider';
import { useVetPendingRequests } from '@/lib/appointmentRequestService';
import { useRooms } from '@/lib/chatService';
import { AppLayout, type NavItem } from './AppLayout';
import { t } from '@/i18n';
import { VetDashboard } from '@/features/vet/VetDashboard';
import { VetAgendaPage } from '@/features/vet/VetAgendaPage';
import { VetChatPage } from '@/features/vet/VetChatPage';
import { ClientsPage } from '@/features/vet/ClientsPage';
import { ClientDetailPage } from '@/features/vet/ClientDetailPage';
import { ProfileSettingsPage } from '@/features/profile/ProfileSettingsPage';
import { PetForm } from '@/features/pets/PetForm';
import { PetDetailPage } from '@/features/pets/PetDetailPage';
import { IncomingMessageToast } from '@/features/chat/IncomingMessageToast';
import { CancelledAppointmentToast } from '@/features/vet/CancelledAppointmentToast';

export function VetApp() {
  const { firebaseUser, profile, signOutUser } = useAuth();
  const pending = useVetPendingRequests(firebaseUser?.uid ?? '');
  const { unread } = useRooms('vetId', firebaseUser?.uid ?? '');

  const nav: NavItem[] = [
    { to: '/', label: t('nav.dashboard'), icon: LayoutDashboard, end: true },
    { to: '/agenda', label: t('nav.agenda'), icon: CalendarDays, badge: pending.length },
    { to: '/clients', label: t('nav.clients'), icon: Users },
    { to: '/chat', label: t('nav.chat'), icon: MessageCircle, badge: unread },
    { to: '/profile', label: t('nav.profile'), icon: User },
  ];

  return (
    <AppLayout
      nav={nav}
      userName={profile?.displayName?.trim() || profile?.email || t('common.vet')}
      userSubtitle={t('common.vet')}
      onSignOut={() => void signOutUser()}
    >
      <IncomingMessageToast />
      <CancelledAppointmentToast />
      <Routes>
        <Route index element={<VetDashboard />} />
        <Route path="agenda" element={<VetAgendaPage />} />
        <Route path="clients" element={<ClientsPage />} />
        <Route path="clients/:ownerId" element={<ClientDetailPage />} />
        <Route path="clients/:ownerId/pets/new" element={<PetForm />} />
        <Route path="clients/:ownerId/pets/:petId" element={<PetDetailPage />} />
        <Route path="clients/:ownerId/pets/:petId/edit" element={<PetForm />} />
        <Route path="chat" element={<VetChatPage />} />
        <Route path="profile" element={<ProfileSettingsPage />} />
        {/* Old links */}
        <Route path="requests" element={<Navigate to="/agenda" replace />} />
        <Route path="patients/*" element={<Navigate to="/clients" replace />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AppLayout>
  );
}
