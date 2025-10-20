# Pages Organization Structure

## Overview

The pages have been reorganized into a clear, maintainable structure based on user types. This makes it easier to find pages and understand which features are available to each user role.

---

## Directory Structure

```
lib/pages/
├── petOwners/              # Pet Owner specific pages
│   ├── modern_dashboard_page.dart    # Main dashboard
│   ├── modern_pets_page.dart         # Pets management
│   ├── modern_calendar_page.dart     # Calendar/appointments
│   ├── modern_chat_page.dart         # Chat list
│   ├── chat_page.dart                # Legacy chat list (backup)
│   ├── chat_room_page.dart           # Individual chat room
│   ├── pets_page.dart                # Legacy pets page (backup)
│   └── pet_symptoms_page.dart        # Pet symptoms tracking
│
├── vets/                   # Veterinarian specific pages
│   ├── vet_home_page.dart            # Vet dashboard
│   ├── vet_management_page.dart      # Vet profile management
│   ├── vet_patients_page.dart        # Patient list
│   └── patient_detail_page.dart      # Individual patient details
│
├── clinicAdmins/           # Clinic Administrator pages
│   ├── clinic_admin_dashboard.dart   # Admin dashboard
│   └── clinic_management_page.dart   # Clinic settings/management
│
├── appOwner/               # App Owner/Super Admin pages
│   ├── admin_dashboard.dart          # System admin dashboard
│   └── app_owner_stats.dart          # App-wide statistics
│
└── (shared pages in root)  # Pages used by multiple user types
    ├── onboarding_pages.dart         # Onboarding flow for all users
    └── add_symptom_sheet.dart        # Symptom entry sheet (used by multiple pages)
```

---

## User Type Access

### Pet Owners (`pages/petOwners/`)

**Primary Users**: Pet owners managing their pets' health and care

**Pages**:

- **Modern Dashboard** - Personalized greeting, quick actions, stats, and event overview
- **Modern Pets** - Grid view of pets with search and filtering
- **Modern Calendar** - Event management with three tabs (Overview, Appointments, Medications)
- **Modern Chat** - Communication with veterinary clinics
- **Chat Room** - Individual conversation view
- **Pet Symptoms** - Tracking and logging pet symptoms

**Access Pattern**: After authentication → `MyHomePage` (main navigation)

---

### Veterinarians (`pages/vets/`)

**Primary Users**: Veterinarians providing care and consultations

**Pages**:

- **Vet Home** - Vet-specific dashboard and overview
- **Vet Management** - Profile and availability management
- **Vet Patients** - List of assigned patients
- **Patient Detail** - Detailed view of individual patient records

**Access Pattern**: After authentication → `VetHomePage`

---

### Clinic Administrators (`pages/clinicAdmins/`)

**Primary Users**: Clinic administrators managing clinic operations

**Pages**:

- **Clinic Admin Dashboard** - Clinic overview and statistics
- **Clinic Management** - Clinic settings, staff management, and configuration

**Access Pattern**: After authentication → `ClinicAdminDashboard`

---

### App Owners (`pages/appOwner/`)

**Primary Users**: System administrators overseeing the entire application

**Pages**:

- **Admin Dashboard** - System-wide overview and controls
- **App Owner Stats** - Global statistics and analytics

**Access Pattern**: After authentication → `AdminDashboard`

---

## Import Path Examples

### From main.dart

```dart
// Pet Owner Pages
import 'pages/petOwners/modern_dashboard_page.dart';
import 'pages/petOwners/modern_pets_page.dart';
import 'pages/petOwners/modern_calendar_page.dart';
import 'pages/petOwners/modern_chat_page.dart';

// Vet Pages
import 'pages/vets/vet_home_page.dart';

// Clinic Admin Pages
import 'pages/clinicAdmins/clinic_admin_dashboard.dart';

// App Owner Pages
import 'pages/appOwner/admin_dashboard.dart';

// Shared Pages
import 'pages/onboarding_pages.dart';
import 'pages/add_symptom_sheet.dart';
```

### From auth_wrapper.dart (core/auth/)

```dart
// Import from pages folders
import '../../pages/onboarding_pages.dart';
import '../../pages/appOwner/admin_dashboard.dart';
import '../../pages/clinicAdmins/clinic_admin_dashboard.dart';
import '../../pages/vets/vet_home_page.dart';
```

### From a page within petOwners/

```dart
// Import sibling page in same folder
import 'chat_room_page.dart';

// Import from other folders
import '../add_symptom_sheet.dart';           // Shared page
import '../../widgets/simple_event_forms.dart'; // Widgets
import '../../theme/app_theme.dart';            // Theme
```

---

## Design System Pages

All **modern pages** (prefixed with `modern_`) follow the new design system:

### Common Features

✅ Modern, clean UI with card-based layouts  
✅ Smooth animations using `flutter_animate`  
✅ Consistent spacing and typography  
✅ Gradient avatars and icon backgrounds  
✅ Beautiful empty states with animations  
✅ Loading states with shimmer effects  
✅ Proper color theming (light/dark mode)  
✅ Accessible design (WCAG AA compliant)

### Legacy vs Modern

| Legacy Page                      | Modern Page           | Status    |
| -------------------------------- | --------------------- | --------- |
| `DashboardPage` (in main.dart)   | `ModernDashboardPage` | ✅ Active |
| `PetsPage`                       | `ModernPetsPage`      | ✅ Active |
| `AppointmentsPage` (in widgets/) | `ModernCalendarPage`  | ✅ Active |
| `ChatPage`                       | `ModernChatPage`      | ✅ Active |

**Note**: Legacy pages are kept as backups but are no longer actively used in navigation.

---

## Navigation Setup

### Main Navigation (`main.dart`)

```dart
final List<Widget> _pages = [
  const ModernDashboardPage(),    // Tab 1: Dashboard
  const ModernPetsPage(),          // Tab 2: Pets
  const ModernCalendarPageWrapper(), // Tab 3: Calendar
  const ModernChatPageWrapper(),   // Tab 4: Chat
];
```

### Bottom Navigation Bar

```dart
BottomNavigationBar(
  items: [
    BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
    BottomNavigationBarItem(icon: Icon(Icons.pets), label: 'Pets'),
    BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Calendar'), // ✨ Renamed from "Appointments"
    BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
  ],
)
```

---

## File Organization Best Practices

### 1. **User Type Segregation**

- Each user type has its own folder
- Clear separation of concerns
- Easy to find and maintain user-specific features

### 2. **Shared Resources**

- Common pages stay in root `pages/` folder
- Widgets in `widgets/` folder
- Services in `services/` folder
- Models in `models/` folder

### 3. **Naming Conventions**

- **Modern pages**: Prefix with `modern_` to indicate new design system
- **User-specific**: Use descriptive names (`vet_home_page`, `clinic_admin_dashboard`)
- **Descriptive**: Name clearly describes the page's purpose

### 4. **Import Organization**

```dart
// Flutter/Dart packages first
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Theme and core
import '../../theme/app_theme.dart';
import '../../core/auth/auth_wrapper.dart';

// Models
import '../../models/event_model.dart';

// Providers
import '../../providers/event_provider.dart';

// Services
import '../../services/pet_service.dart';

// Widgets
import '../../widgets/simple_event_forms.dart';

// Local/sibling imports
import 'chat_room_page.dart';
```

---

## Migration Notes

### What Changed

1. ✅ Moved pet owner pages to `pages/petOwners/`
2. ✅ Moved vet pages to `pages/vets/`
3. ✅ Moved clinic admin pages to `pages/clinicAdmins/`
4. ✅ Moved app owner pages to `pages/appOwner/`
5. ✅ Updated all imports in `main.dart` and `auth_wrapper.dart`
6. ✅ Deleted old `features/` folder structure
7. ✅ Calendar tab renamed from "Appointments" to "Calendar"

### No Breaking Changes

- All existing functionality preserved
- Modern pages are drop-in replacements
- Legacy pages kept as backups
- No API or model changes

---

## Future Enhancements

### Potential Additions

**Pet Owners**:

- Pet health records page
- Vaccination history page
- Appointment history page

**Vets**:

- Prescription management page
- Patient notes page
- Schedule management page

**Clinic Admins**:

- Staff management page
- Billing/payments page
- Reports and analytics page

**Shared**:

- Profile settings page
- Notification settings page
- Help/support page

---

## Testing Checklist

✅ All pages accessible via navigation  
✅ No linter errors  
✅ Imports resolve correctly  
✅ Pet owner flow works end-to-end  
✅ Vet flow works end-to-end  
✅ Clinic admin flow works end-to-end  
✅ App owner flow works end-to-end  
✅ Theme switching works across all pages  
✅ Animations perform smoothly  
✅ Empty states display correctly  
✅ Loading states display correctly

---

## Quick Reference

| User Type        | Entry Point            | Main Pages                      | Folder                |
| ---------------- | ---------------------- | ------------------------------- | --------------------- |
| **Pet Owner**    | `MyHomePage`           | Dashboard, Pets, Calendar, Chat | `pages/petOwners/`    |
| **Veterinarian** | `VetHomePage`          | Home, Patients, Management      | `pages/vets/`         |
| **Clinic Admin** | `ClinicAdminDashboard` | Dashboard, Management           | `pages/clinicAdmins/` |
| **App Owner**    | `AdminDashboard`       | Dashboard, Stats                | `pages/appOwner/`     |

---

**Last Updated**: October 20, 2025  
**Flutter Version**: 3.8.1+  
**Organization Status**: ✅ Complete and Production-Ready
