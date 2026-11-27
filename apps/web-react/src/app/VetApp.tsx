import { Routes, Route, Navigate } from 'react-router-dom';
import { LayoutDashboard, CalendarDays, MessageCircle, Users, User, Landmark, Building2 } from 'lucide-react';
import { useAuth } from '@/auth/AuthProvider';
import { useClinicRequests } from '@/lib/appointmentRequestService';
import { useClinicRooms } from '@/lib/chatService';
import { AppointmentRequestStatus } from '@vetplus/shared';
import { AppLayout, type ExternalNavLink, type NavItem } from './AppLayout';
import { ClinicSwitcher } from './ClinicSwitcher';
import { useActiveClinic } from './ClinicProvider';
import { t } from '@/i18n';
import { VetDashboard } from '@/features/vet/VetDashboard';
import { VetAgendaPage } from '@/features/vet/VetAgendaPage';
import { VetChatPage } from '@/features/vet/VetChatPage';
import { ClientsPage } from '@/features/vet/ClientsPage';
import { ClientDetailPage } from '@/features/vet/ClientDetailPage';
import { ProfileSettingsPage } from '@/features/profile/ProfileSettingsPage';
import { PetForm } from '@/features/pets/PetForm';
import { PetDetailPage } from '@/features/pets/PetDetailPage';
import { ClinicSettingsPage } from '@/features/clinic/ClinicSettingsPage';
import { IncomingMessageToast } from '@/features/chat/IncomingMessageToast';
import { CancelledAppointmentToast } from '@/features/vet/CancelledAppointmentToast';
import { NotificationPrompt } from '@/features/notifications/NotificationPrompt';

const PEMV_URL = 'https://pemv.dgav.pt/web/login?redirect=https%3A%2F%2Fpemv.dgav.pt%2Fmy%2Fvet';

export function VetApp() {
  const { firebaseUser, profile, signOutUser } = useAuth();
  const { clinicId, clinic, isOwner } = useActiveClinic();
  const { mine, pool } = useClinicRequests(clinicId, firebaseUser?.uid ?? '');
  const { unread } = useClinicRooms(clinicId, firebaseUser?.uid ?? '');
  const pendingCount =
    mine.filter((r) => r.status === AppointmentRequestStatus.pending).length +
    pool.filter((r) => r.status === AppointmentRequestStatus.pending).length;

  const nav: NavItem[] = [
    { to: '/', label: t('nav.dashboard'), icon: LayoutDashboard, end: true },
    { to: '/agenda', label: t('nav.agenda'), icon: CalendarDays, badge: pendingCount },
    { to: '/clients', label: t('nav.clients'), icon: Users },
    { to: '/chat', label: t('nav.chat'), icon: MessageCircle, badge: unread },
    ...(isOwner ? [{ to: '/clinic', label: t('nav.clinic'), icon: Building2 }] : []),
    { to: '/profile', label: t('nav.profile'), icon: User },
  ];

  const externalLinks: ExternalNavLink[] = [
    { href: PEMV_URL, label: t('nav.pemv'), title: t('nav.pemvTitle'), icon: Landmark },
  ];

  return (
    <AppLayout
      clinic={{ name: clinic?.name ?? '', logoWideUrl: clinic?.brand?.logoWideUrl ?? null }}
      clinicSwitcher={<ClinicSwitcher />}
      nav={nav}
      externalLinks={externalLinks}
      userName={profile?.displayName?.trim() || profile?.email || t('common.vet')}
      userSubtitle={t('common.vet')}
      onSignOut={() => void signOutUser()}
    >
      <IncomingMessageToast />
      <CancelledAppointmentToast />
      <NotificationPrompt />
      <Routes>
        <Route index element={<VetDashboard />} />
        <Route path="agenda" element={<VetAgendaPage />} />
        <Route path="clients" element={<ClientsPage />} />
        <Route path="clients/:ownerId" element={<ClientDetailPage />} />
        <Route path="clients/:ownerId/pets/new" element={<PetForm />} />
        <Route path="clients/:ownerId/pets/:petId" element={<PetDetailPage />} />
        <Route path="clients/:ownerId/pets/:petId/edit" element={<PetForm />} />
        <Route path="chat" element={<VetChatPage />} />
        <Route
          path="clinic"
          element={isOwner ? <ClinicSettingsPage /> : <Navigate to="/" replace />}
        />
        <Route path="profile" element={<ProfileSettingsPage />} />
        {/* Old links */}
        <Route path="requests" element={<Navigate to="/agenda" replace />} />
        <Route path="patients/*" element={<Navigate to="/clients" replace />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AppLayout>
  );
}
