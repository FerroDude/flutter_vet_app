import { Routes, Route, Navigate } from 'react-router-dom';
import { LayoutDashboard, Building2, BarChart3, User } from 'lucide-react';
import { useAuth } from '@/auth/AuthProvider';
import { AppLayout, type NavItem } from './AppLayout';
import { AppOwnerDashboard } from '@/features/appOwner/AppOwnerDashboard';
import { ClinicsAdminPage } from '@/features/appOwner/ClinicsAdminPage';
import { AppOwnerStatsPage } from '@/features/appOwner/AppOwnerStatsPage';
import { ProfileSettingsPage } from '@/features/profile/ProfileSettingsPage';

const NAV: NavItem[] = [
  { to: '/', label: 'Dashboard', icon: LayoutDashboard, end: true },
  { to: '/clinics', label: 'Clinics', icon: Building2 },
  { to: '/stats', label: 'Analytics', icon: BarChart3 },
  { to: '/profile', label: 'Profile', icon: User },
];

export function AppOwnerApp() {
  const { profile, signOutUser } = useAuth();

  return (
    <AppLayout
      nav={NAV}
      userName={profile?.displayName?.trim() || profile?.email || 'App owner'}
      userSubtitle="VetPlus administration"
      onSignOut={() => void signOutUser()}
    >
      <Routes>
        <Route index element={<AppOwnerDashboard />} />
        <Route path="clinics" element={<ClinicsAdminPage />} />
        <Route path="stats" element={<AppOwnerStatsPage />} />
        <Route path="profile" element={<ProfileSettingsPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AppLayout>
  );
}
