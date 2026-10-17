import { Routes, Route, Navigate } from 'react-router-dom';
import {
  LayoutDashboard,
  CalendarClock,
  MessageCircle,
  Users,
  Stethoscope,
  Settings,
  User,
} from 'lucide-react';
import { useAuth, type Role } from '@/auth/AuthProvider';
import { AppLayout, type NavItem } from './AppLayout';
import { StaffDashboard } from '@/features/staff/StaffDashboard';
import { AdminDashboard } from '@/features/staff/AdminDashboard';
import { AppointmentQueuePage } from '@/features/staff/AppointmentQueuePage';
import { StaffChatPage } from '@/features/staff/StaffChatPage';
import { PatientsPage } from '@/features/staff/PatientsPage';
import { PatientDetailPage } from '@/features/staff/PatientDetailPage';
import { StaffManagementPage } from '@/features/staff/StaffManagementPage';
import { ClinicSettingsPage } from '@/features/staff/ClinicSettingsPage';
import { ProfileSettingsPage } from '@/features/profile/ProfileSettingsPage';

const ROLE_LABEL: Partial<Record<Role, string>> = {
  receptionist: 'Receptionist',
  vet: 'Veterinarian',
  clinicAdmin: 'Clinic Admin',
  appOwner: 'App Owner',
};

const DASHBOARD: NavItem = { to: '/', label: 'Dashboard', icon: LayoutDashboard, end: true };
const REQUESTS: NavItem = { to: '/requests', label: 'Requests', icon: CalendarClock };
const PATIENTS: NavItem = { to: '/patients', label: 'Patients', icon: Users };
const STAFF: NavItem = { to: '/staff', label: 'Staff', icon: Stethoscope };
const CHAT: NavItem = { to: '/chat', label: 'Chat', icon: MessageCircle };
const SETTINGS: NavItem = { to: '/settings', label: 'Settings', icon: Settings };
const PROFILE: NavItem = { to: '/profile', label: 'Profile', icon: User };

const NAV_BY_ROLE: Partial<Record<Role, NavItem[]>> = {
  receptionist: [DASHBOARD, REQUESTS, PATIENTS, CHAT, PROFILE],
  vet: [DASHBOARD, PATIENTS, CHAT, PROFILE],
  clinicAdmin: [DASHBOARD, STAFF, PATIENTS, CHAT, SETTINGS, PROFILE],
};

export function StaffApp() {
  const { profile, role, connectedClinic, signOutUser } = useAuth();
  const nav = NAV_BY_ROLE[role] ?? [DASHBOARD, CHAT, PROFILE];
  const isAdmin = role === 'clinicAdmin';
  const showRequests = role === 'receptionist';

  return (
    <AppLayout
      nav={nav}
      userName={profile?.displayName?.trim() || profile?.email || 'Staff'}
      userSubtitle={connectedClinic?.name ?? ROLE_LABEL[role] ?? 'Clinic staff'}
      onSignOut={() => void signOutUser()}
    >
      <Routes>
        <Route
          index
          element={isAdmin ? <AdminDashboard /> : <StaffDashboard showRequests={showRequests} />}
        />
        {showRequests && <Route path="requests" element={<AppointmentQueuePage />} />}
        <Route path="patients" element={<PatientsPage />} />
        <Route path="patients/:ownerId" element={<PatientDetailPage />} />
        {isAdmin && <Route path="staff" element={<StaffManagementPage />} />}
        {isAdmin && <Route path="settings" element={<ClinicSettingsPage />} />}
        <Route path="chat" element={<StaffChatPage />} />
        <Route path="profile" element={<ProfileSettingsPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AppLayout>
  );
}
