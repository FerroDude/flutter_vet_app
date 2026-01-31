# Peton Mobile App - Technical Architecture Documentation

> Last Updated: January 2026
>
> This document provides a comprehensive technical overview of the Peton (VetPlus) mobile app, covering architecture, data models, services, state management, styling, and implementation details.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Technology Stack](#2-technology-stack)
3. [Project Structure](#3-project-structure)
4. [App Initialization & Boot Flow](#4-app-initialization--boot-flow)
5. [User Roles & Authentication](#5-user-roles--authentication)
6. [State Management](#6-state-management)
7. [Data Models](#7-data-models)
8. [Services Layer](#8-services-layer)
9. [Firebase Integration](#9-firebase-integration)
10. [Theming & Styling](#10-theming--styling)
11. [UI Components](#11-ui-components)
12. [Navigation & Routing](#12-navigation--routing)
13. [Chat System](#13-chat-system)
14. [Appointment Request System](#14-appointment-request-system)
15. [Media Handling](#15-media-handling)
16. [Push Notifications](#16-push-notifications)
17. [Security Rules](#17-security-rules)
18. [Feature Summary by Role](#18-feature-summary-by-role)

---

## 1. Project Overview

**Peton** (internally "VetPlus") is a multi-tenant Flutter mobile application that facilitates communication between pet owners and veterinary clinics. The app supports different user roles with distinct functionalities and is built on Firebase for backend services.

### Key Characteristics

- **Platform:** Flutter (Android/iOS)
- **Backend:** Firebase (Auth, Firestore, Realtime Database, Storage, Cloud Functions, FCM)
- **State Management:** Provider with ChangeNotifier pattern
- **Architecture:** Service-Repository-Provider pattern
- **Design System:** Custom theme with Material 3, Google Fonts (Inter), responsive sizing with ScreenUtil

---

## 2. Technology Stack

### Core Dependencies

| Category      | Package                  | Version | Purpose                               |
| ------------- | ------------------------ | ------- | ------------------------------------- |
| **Firebase**  | `firebase_core`          | ^4.0.0  | Firebase initialization               |
|               | `firebase_auth`          | ^6.0.0  | Email/password authentication         |
|               | `cloud_firestore`        | ^6.0.0  | NoSQL database                        |
|               | `firebase_database`      | ^12.0.0 | Realtime Database (typing indicators) |
|               | `firebase_storage`       | ^13.0.0 | Media file storage                    |
|               | `firebase_messaging`     | ^16.0.0 | Push notifications (FCM)              |
|               | `cloud_functions`        | 6.0.0   | Cloud Functions integration           |
| **State**     | `provider`               | ^6.1.1  | State management                      |
| **UI/UX**     | `flutter_screenutil`     | ^5.9.3  | Responsive sizing                     |
|               | `google_fonts`           | ^6.2.1  | Typography (Inter font)               |
|               | `getwidget`              | ^7.0.0  | UI component library                  |
|               | `gap`                    | ^3.0.1  | Spacing widgets                       |
|               | `table_calendar`         | ^3.1.2  | Calendar widget                       |
| **Media**     | `image_picker`           | ^1.1.2  | Image/video selection                 |
|               | `file_picker`            | ^8.1.7  | File selection                        |
|               | `flutter_image_compress` | ^2.3.0  | Image compression                     |
|               | `cached_network_image`   | ^3.4.1  | Image caching                         |
|               | `video_player`           | ^2.9.2  | Video playback                        |
|               | `chewie`                 | ^1.8.5  | Video player UI                       |
|               | `audio_waveforms`        | ^1.2.0  | Voice message recording               |
| **Chat**      | `emoji_picker_flutter`   | ^4.4.0  | Emoji selection                       |
|               | `any_link_preview`       | ^3.0.2  | URL link previews                     |
|               | `url_launcher`           | ^6.3.1  | Opening URLs                          |
| **Storage**   | `shared_preferences`     | ^2.2.2  | Local key-value storage               |
|               | `path_provider`          | ^2.1.5  | File system paths                     |
| **Utilities** | `intl`                   | ^0.20.2 | Internationalization/formatting       |
|               | `uuid`                   | ^4.4.2  | UUID generation                       |
|               | `timezone`               | ^0.9.4  | Timezone handling                     |
|               | `permission_handler`     | ^11.3.1 | Runtime permissions                   |

### Flutter/Dart Version

```yaml
environment:
  sdk: ^3.8.1
```

---

## 3. Project Structure

```
lib/
├── main.dart                    # App entry point
├── app.dart                     # MyApp widget definition
├── firebase_options.dart        # Firebase configuration (auto-generated)
│
├── core/
│   └── auth/
│       ├── auth_wrapper.dart        # Authentication gating & role routing
│       ├── auth_page.dart           # Login/signup UI
│       ├── email_verification_page.dart
│       ├── display_name_setup_page.dart
│       ├── forgot_password_page.dart
│       └── app_lifecycle_wrapper.dart # Handles app lifecycle for delivery receipts
│
├── models/
│   ├── clinic_models.dart       # UserProfile, Clinic, ClinicMember, enums
│   ├── chat_models.dart         # ChatRoom, ChatMessage, enums
│   ├── event_model.dart         # CalendarEvent, AppointmentEvent, MedicationEvent, NoteEvent
│   ├── pet_model.dart           # Pet model
│   ├── symptom_models.dart      # Symptom tracking models
│   ├── medication_model.dart    # Standalone medication tracking
│   ├── notification_service.dart # Notification model/service (placeholder)
│   ├── calendar_service.dart    # Calendar-related models
│   └── appointment_request_model.dart # Appointment request system
│
├── services/
│   ├── clinic_service.dart      # Clinic CRUD, user management, invites
│   ├── chat_service.dart        # Chat room & message operations
│   ├── pet_service.dart         # Pet CRUD operations
│   ├── cache_service.dart       # SharedPreferences caching
│   ├── media_cache_service.dart # Media file caching
│   ├── media_service.dart       # Media upload/download
│   ├── push_notification_service.dart # FCM token management
│   └── appointment_request_service.dart # Appointment requests
│
├── repositories/
│   ├── event_repository.dart    # Calendar events (Firestore + caching)
│   └── medication_repository.dart # Medication tracking
│
├── providers/
│   ├── user_provider.dart       # User state, auth, clinic connection
│   ├── chat_provider.dart       # Chat rooms, messages, media upload
│   ├── event_provider.dart      # Calendar events
│   ├── vet_provider.dart        # Vet-specific operations
│   ├── medication_provider.dart # Medication management
│   └── appointment_request_provider.dart # Appointment request state
│
├── pages/
│   ├── onboarding_pages.dart    # Clinic selection for new users
│   ├── petOwners/               # Pet owner screens
│   │   ├── home_page.dart       # Main navigation (Dashboard/Calendar/Chat)
│   │   ├── dashboard_page.dart  # Pet owner dashboard
│   │   ├── calendar_page.dart   # Calendar view
│   │   ├── chat_page.dart       # Chat list
│   │   ├── chat_room_page.dart  # Individual chat conversation
│   │   ├── pets_page.dart       # Pet list
│   │   ├── pet_details_page.dart
│   │   ├── profile_page.dart
│   │   └── settings_page.dart
│   ├── vets/                    # Vet screens
│   │   ├── vet_home_page.dart   # Vet main navigation
│   │   ├── vet_dashboard_page.dart
│   │   ├── vet_patients_page.dart
│   │   └── vet_management_page.dart
│   ├── clinicAdmins/            # Clinic admin screens
│   │   ├── clinic_admin_dashboard.dart
│   │   ├── clinic_management_page.dart
│   │   └── receptionist_management_page.dart
│   ├── receptionists/           # Receptionist screens
│   │   ├── receptionist_home_page.dart
│   │   ├── receptionist_dashboard_page.dart
│   │   ├── receptionist_clinic_page.dart  # Unified chats + appointments
│   │   └── appointment_requests_page.dart
│   └── appOwner/                # App owner (super admin) screens
│       ├── admin_dashboard.dart
│       └── app_owner_stats.dart
│
├── widgets/                     # Feature-specific widgets
│   ├── calendar_view.dart
│   ├── event_forms.dart
│   ├── medication_widgets.dart
│   └── ...
│
├── shared/
│   └── widgets/                 # Reusable UI components
│       ├── app_components.dart  # AppCard, AppButton, AppTextField, etc.
│       ├── chat_widgets.dart    # Chat-specific widgets
│       ├── gradient_background.dart
│       ├── info_card.dart
│       ├── notification_badge.dart
│       └── ...
│
├── theme/
│   ├── app_theme.dart           # Color palette, ThemeData, extensions
│   ├── theme_manager.dart       # Theme state management
│   ├── design_tokens.json       # Design token definitions
│   └── README.md
│
└── utils/
    ├── performance_utils.dart
    └── cleanup_old_medications.dart
```

---

## 4. App Initialization & Boot Flow

### Entry Point (`main.dart`)

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize services
  final cacheService = CacheService();
  await cacheService.init();
  await MediaCacheService.instance.init();

  final notificationService = NotificationService();
  await notificationService.initialize();

  final pushNotificationService = PushNotificationService();
  await pushNotificationService.initialize();

  runApp(MyApp(...));
}
```

### Provider Hierarchy

```
ScreenUtilInit
└── MultiProvider (Global Services)
    ├── ThemeManager
    ├── CacheService
    ├── NotificationService
    ├── PushNotificationService
    ├── ClinicService
    └── ChatService
    └── MaterialApp
        └── AuthWrapper
            └── MultiProvider (User-Scoped - after auth)
                ├── UserProvider
                ├── EventProvider
                ├── MedicationProvider
                ├── ChatProvider
                ├── VetProvider
                └── AppointmentRequestProvider
                └── AppLifecycleWrapper
                    └── Role-Based Home Page
```

### Authentication Flow

1. **FirebaseAuth.userChanges()** stream monitored in `AuthWrapper`
2. If no user → Show `AuthPage` (login/signup)
3. If user but email not verified → Show `EmailVerificationPage`
4. If authenticated & verified:
   - Load/create `UserProfile` via `UserProvider`
   - Handle temp profile linking (admin/vet/receptionist invites)
   - Route based on user role

---

## 5. User Roles & Authentication

### User Types (Enum Indices)

```dart
enum UserType {
  petOwner,     // 0
  vet,          // 1
  clinicAdmin,  // 2
  appOwner,     // 3
  receptionist  // 4
}

enum ClinicRole {
  admin,        // 0
  vet,          // 1
  receptionist  // 2
}
```

### Role Determination

| Role             | Determination Logic                                                     |
| ---------------- | ----------------------------------------------------------------------- |
| **App Owner**    | `globalType == 'appOwner'` OR email in hardcoded allowlist              |
| **Clinic Admin** | `clinicRole == ClinicRole.admin` AND `connectedClinicId != null`        |
| **Vet**          | `clinicRole == ClinicRole.vet` AND `connectedClinicId != null`          |
| **Receptionist** | `clinicRole == ClinicRole.receptionist` AND `connectedClinicId != null` |
| **Pet Owner**    | Default (none of the above)                                             |

### Invite System (No-Backend Flow)

Staff invitations use a placeholder profile pattern to avoid backend requirements:

1. **Admin invites vet/receptionist by email**
2. **Temp profile created:** `users/temp_vet_{email_token}` or `users/temp_receptionist_{email_token}`
3. **Password reset email sent** via secondary Firebase app instance
4. **On first login:** Real user links to temp profile, membership created, temp deleted

---

## 6. State Management

### Provider Pattern

All providers extend `ChangeNotifier` and follow this pattern:

```dart
class SomeProvider extends ChangeNotifier {
  // Private state
  bool _isLoading = false;
  String? _error;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;

  // State setters with notification
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Public methods for business logic
  Future<void> someAction() async {
    _setLoading(true);
    try {
      // ... operation
    } catch (e) {
      _error = e.toString();
    }
    _setLoading(false);
  }
}
```

### Key Providers

| Provider                     | Responsibility                                                                        |
| ---------------------------- | ------------------------------------------------------------------------------------- |
| `UserProvider`               | User profile, authentication state, clinic connection, role checks, staff invitations |
| `ChatProvider`               | Chat rooms list, messages, media upload, typing status, read receipts, pagination     |
| `EventProvider`              | Calendar events, counts, scheduling                                                   |
| `VetProvider`                | Vet-specific operations, patient list                                                 |
| `MedicationProvider`         | Medication tracking and reminders                                                     |
| `AppointmentRequestProvider` | Appointment request CRUD                                                              |

### Data Flow

```
UI Widget
    ↓ (dispatches action)
Provider
    ↓ (calls)
Service / Repository
    ↓ (performs)
Firebase (Firestore/Auth/Storage)
    ↓ (returns data)
Service / Repository
    ↓ (transforms)
Provider (updates state, notifyListeners())
    ↓
UI Widget (rebuilds via Consumer/Provider.of)
```

---

## 7. Data Models

### UserProfile

```dart
class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final UserType userType;
  final String? connectedClinicId;
  final ClinicRole? clinicRole;
  final String? phone;
  final String? address;
  final bool hasSkippedClinicSelection;
  final bool mustChangePassword;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final String? globalType;  // 'appOwner' or null
  final String? fcmToken;

  // Helper getters
  bool get isAppOwner => ...;
  bool get isClinicAdmin => ...;
  bool get isVet => ...;
  bool get isReceptionist => ...;
  bool get isPetOwner => ...;
  bool get hasClinicConnection => ...;
}
```

### Clinic & ClinicMember

```dart
class Clinic {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String email;
  final String adminId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final String? website;
  final String? description;
  final Map<String, dynamic>? businessHours;
}

class ClinicMember {
  final String userId;
  final String clinicId;
  final ClinicRole role;
  final List<String> permissions;  // Empty for vets (full access)
  final DateTime addedAt;
  final String addedBy;
  final bool isActive;
  final DateTime? lastActive;
}
```

### ChatRoom & ChatMessage

```dart
enum ChatRoomStatus { pending, active, closed }
enum MessageType { text, image, video, file, voice, appointment, medication }
enum MessageStatus { sent, delivered, read }

class ChatRoom {
  final String id;
  final String clinicId;
  final String petOwnerId;
  final String petOwnerName;
  final String vetId;
  final String vetName;
  final List<String> petIds;
  final ChatMessage? lastMessage;
  final Map<String, int> unreadCounts;  // userId -> count
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final String? topic;
  final ChatRoomStatus status;
  final String? requestDescription;
  final String? initiatedBy;  // 'pet_owner', 'vet', 'receptionist'
  final String? staffRole;
}

class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String senderRole;  // 'pet_owner', 'vet', 'admin', 'receptionist'
  final String content;
  final MessageType type;
  final MessageStatus status;
  final DateTime timestamp;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final int? audioDuration;
  final String? appointmentId;
  final String? medicationId;
  final Map<String, dynamic>? metadata;  // Replies, reactions
  final bool isDeleted;
  final DateTime? deletedAt;
}
```

### Calendar Events (Inheritance)

```dart
enum EventType { appointment, medication, note }

abstract class CalendarEvent {
  final String id;
  final String title;
  final String description;
  final DateTime dateTime;
  final EventType type;
  final String? petId;
  final String userId;
  final String? seriesId;
  final bool isRecurring;
  final String? recurrencePattern;
  final int? recurrenceInterval;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class AppointmentEvent extends CalendarEvent {
  final String? vetName;
  final String? location;
  final String? appointmentType;
  final bool isConfirmed;
  final String? contactInfo;
}

class MedicationEvent extends CalendarEvent {
  final String medicationName;
  final String dosage;
  final String frequency;
  final int? customIntervalMinutes;
  final bool isCompleted;
  final DateTime? lastTaken;
  final DateTime? nextDose;
  final int? remainingDoses;
  final String? instructions;
  final bool requiresNotification;
}

class NoteEvent extends CalendarEvent {
  final String? category;
  final int priority;
  final bool isCompleted;
  final List<String>? tags;
  final DateTime? reminderDateTime;
}
```

### Pet

```dart
class Pet {
  final String id;
  final String ownerId;
  final String name;
  final String? species;
  final String? breed;
  final String? sex;
  final DateTime? birthDate;
  final double? weightKg;
  final String? microchip;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

### Date Serialization

All models support flexible date parsing:

```dart
static DateTime _parseDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.parse(value);
  throw ArgumentError('Invalid datetime value');
}
```

**Stored as:** epoch milliseconds (int) in Firestore for consistency.

---

## 8. Services Layer

### ClinicService

Handles all clinic-related operations:

- **Clinic CRUD:** `createClinic`, `getClinic`, `updateClinic`, `searchClinics`
- **User-Clinic Connection:** `connectUserToClinic`, `disconnectUserFromClinic`
- **Member Management:** `addVetToClinic`, `removeMemberFromClinic`, `getClinicMembers`
- **Invite System:** `createVetInvite`, `createReceptionistInvite`, `revokeVetInvite`
- **User Profiles:** `createUserProfile`, `updateUserProfile`, `getUserProfile`, `deleteUserProfile`
- **Streams:** `clinicStream`, `userProfileStream`, `clinicMembersStream`, `clinicPatientsStream`

### ChatService

Handles all chat operations:

- **Room Management:** `createChatRoom`, `findOrCreateOneOnOneChat`, `createStaffInitiatedChat`, `getChatRoom`
- **Chat Requests:** `createChatRequest`, `acceptChatRequest`, `deleteChatRequest`
- **Messages:** `sendMessage`, `getMessages`, `getOlderMessages`, `deleteMessages`
- **Read Receipts:** `markMessagesAsRead`, `markMessagesAsDelivered`, `markMessagesAsReadStatus`
- **Typing Status:** `updateTypingStatus`, `typingStatusStream` (uses Realtime Database)
- **Reactions:** `toggleReaction`
- **Streams:** `vetChatRoomsStream`, `clinicChatRoomsStream`, `petOwnerChatRoomsStream`, `messagesStream`

### MediaService

Handles media operations:

- **Picking:** `pickImage`, `pickVideo`, `pickFiles`
- **Upload:** `uploadMedia`, `uploadVoiceMessage`
- **Voice Recording:** `startRecording`, `stopRecording`, `cancelRecording`
- **Compression:** Image and video compression before upload

### CacheService

Local caching with SharedPreferences:

- Event counts caching
- Offline edit queue
- Theme preferences

### PushNotificationService

FCM token management:

- `initialize()` - Request permissions, get token
- `saveTokenForUser(userId)` - Store token in Firestore
- `clearTokenForUser(userId)` - Remove token on logout

---

## 9. Firebase Integration

### Firestore Collections

```
/users/{userId}
├── /events/{eventId}           # Calendar events
├── /clinicHistory/{historyId}  # Clinic join/leave records
├── /pets/{petId}               # User's pets
│   ├── /symptoms/{symptomId}   # Pet symptoms
│   └── /medications/{medicationId}  # Pet medications

/clinics/{clinicId}
├── /members/{userId}           # Clinic staff members
└── /invites/{inviteId}         # Pending staff invites

/chatRooms/{chatRoomId}
└── /messages/{messageId}       # Chat messages

/appointmentRequests/{requestId}  # Appointment requests from pet owners
```

### Firebase Realtime Database

Used for real-time typing indicators:

```
/typing/{chatRoomId}/{userId}
├── isTyping: boolean
└── timestamp: ServerValue.timestamp
```

Typing status auto-expires after 3 seconds of inactivity.

### Firebase Storage

```
/chat_uploads/{chatRoomId}/
├── images/{uuid}.jpg
├── videos/{uuid}.mp4
├── thumbnails/{uuid}_thumb.jpg
├── voice/{uuid}.m4a
└── files/{uuid}_{filename}
```

### Cloud Functions

Located in `functions/` directory:

- Push notification triggers on new messages
- Background data processing (if implemented)

---

## 10. Theming & Styling

### Design System Overview

The app uses a custom Material 3 theme with:

- **Typography:** Google Fonts Inter
- **Responsive Sizing:** flutter_screenutil (design size: 375x812)
- **Theme Mode:** Light mode only (dark mode disabled but configured)

### Color Palette

```dart
// Navy/Slate Professional Palette (Light Mode)
static const Color neutral50 = Color(0xFFFFFFFF);   // Pure white - backgrounds
static const Color neutral100 = Color(0xFFF8F9FA); // Off-white - secondary surfaces
static const Color neutral200 = Color(0xFFCCC9DC); // Light lavender gray - borders
static const Color neutral400 = Color(0xFF324A5F); // Medium slate blue - accents
static const Color neutral500 = Color(0xFF1B2A41); // Dark navy blue - primary
static const Color neutral700 = Color(0xFF0C1821); // Very dark navy - strong accents
static const Color neutral900 = Color(0xFF000000); // Pure black - primary text

// Brand Colors
static const Color brandBlue = Color(0xFF1172B0);
static const Color brandTeal = Color(0xFF57B4A4);   // Medications/secondary
static const Color brandMint = Color(0xFF85E7A9);

// Semantic Colors
static const Color success = Color(0xFF10B981);
static const Color warning = Color(0xFFF59E0B);
static const Color error = Color(0xFFEF4444);
```

### Spacing & Radius System

```dart
// Spacing (responsive with .w suffix)
static double spacing1 = 4.0.w;
static double spacing2 = 8.0.w;
static double spacing3 = 12.0.w;
static double spacing4 = 16.0.w;
static double spacing5 = 20.0.w;
static double spacing6 = 24.0.w;
static double spacing8 = 32.0.w;
static double spacing12 = 48.0.w;

// Border Radius (responsive with .r suffix)
static double radius1 = 4.0.r;
static double radius2 = 8.0.r;
static double radius3 = 12.0.r;
static double radius4 = 16.0.r;
```

### Gradient Background

```dart
static const LinearGradient backgroundGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFF1B2A41),  // Dark navy
    Color(0xFF1E3147),  // Slightly lighter
    Color(0xFF21374D),  // More lighter
    Color(0xFF243D53),  // Lightest navy
  ],
  stops: [0.0, 0.3, 0.6, 1.0],
);
```

### Theme Extensions

Context extensions for easy access:

```dart
extension ThemeContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get surface => isDark ? darkBackgroundSecondary : neutral50;
  Color get textPrimary => isDark ? darkTextPrimary : neutral900;
  Color get textSecondary => isDark ? darkTextSecondary : neutral700;
  Color get border => isDark ? Color(0xFF1E293B) : neutral200;
  Color get primaryColor => isDark ? brandBlueLight : neutral500;
  // ... more getters
}
```

### Using the Theme

```dart
// In widgets:
Container(
  color: context.surface,
  child: Text(
    'Hello',
    style: GoogleFonts.inter(
      fontSize: 14.sp,
      color: context.textPrimary,
    ),
  ),
);

// Spacing
Gap(AppTheme.spacing4),
Padding(padding: EdgeInsets.all(AppTheme.spacing3)),

// Border radius
BorderRadius.circular(AppTheme.radius3),
```

---

## 11. UI Components

### Shared Components (`lib/shared/widgets/app_components.dart`)

| Component             | Purpose                                         |
| --------------------- | ----------------------------------------------- |
| `AppCard`             | Styled container with optional tap handler      |
| `AppButton`           | Primary elevated button with loading state      |
| `AppOutlineButton`    | Outlined button variant                         |
| `AppTextField`        | Styled text input with validation               |
| `AppSection`          | Section header with optional trailing widget    |
| `AppListTile`         | Custom list tile with icon, title, subtitle     |
| `AppIconButton`       | Bordered icon button                            |
| `AppEmptyState`       | Empty state with icon, message, optional action |
| `AppChip`             | Tag/chip component                              |
| `AppLoadingIndicator` | Centered loading spinner                        |

### Usage Example

```dart
AppCard(
  onTap: () => handleTap(),
  padding: EdgeInsets.all(AppTheme.spacing4),
  child: Column(
    children: [
      AppSection(
        title: 'My Pets',
        trailing: AppIconButton(
          icon: Icons.add,
          onPressed: () => addPet(),
        ),
        child: Column(
          children: pets.map((pet) => AppListTile(
            icon: Icons.pets,
            title: pet.name,
            subtitle: pet.breed,
            onTap: () => viewPet(pet),
          )).toList(),
        ),
      ),
    ],
  ),
);
```

### Gradient Background

Pages use a gradient background wrapper:

```dart
// In GradientBackground widget or directly:
Container(
  decoration: BoxDecoration(
    gradient: AppTheme.backgroundGradient,
  ),
  child: SafeArea(
    child: // ... content
  ),
);
```

---

## 12. Navigation & Routing

### Role-Based Routing (in AuthWrapper)

```dart
if (userProvider.isAppOwner) {
  return const AdminDashboard();
}
if (userProvider.isClinicAdmin) {
  return const ClinicAdminDashboard();
}
if (userProvider.isVet) {
  return const VetHomePage();
}
if (userProvider.isReceptionist) {
  return const ReceptionistHomePage();
}
// Default: Pet Owner
return MyHomePage(title: 'VetPlus');
```

### Pet Owner Navigation (Bottom Navigation)

```dart
// MyHomePage tabs
Index 0: DashboardPage
Index 1: CalendarPageWrapper (Calendar/Appointments)
Index 2: ClinicPage (Clinic Communication - Chats & Appointments)
```

The **ClinicPage** combines chat conversations and appointment requests in a unified feed with:
- Filter chips: All, Chats, Appointments (with badge counts)
- Combined feed sorted by pending items first, then recent activity
- Chat cards with unread indicators and pet info
- Appointment cards with status badges
- Dynamic FAB based on selected filter

### Receptionist Navigation (Bottom Navigation)

```dart
// ReceptionistHomePage tabs
Index 0: ReceptionistDashboardPage
Index 1: VetPatientsPage (Patients)
Index 2: ReceptionistClinicPage (Unified Chats & Appointments)
```

The **ReceptionistClinicPage** mirrors the pet owner's ClinicPage but with staff-specific actions:
- Filter chips: All, Chats, Appointments (with badge counts for pending items)
- Chat request cards with "Accept" button
- Appointment request cards with Deny/Chat/Confirm actions
- Active chat cards with unread indicators
- Search functionality across all items

### Navigator Key

Global navigator key for programmatic navigation:

```dart
// In main.dart
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// In MaterialApp
MaterialApp(
  navigatorKey: navigatorKey,
  // ...
);

// Usage anywhere
navigatorKey.currentState?.push(MaterialPageRoute(...));
```

---

## 13. Chat System

### Chat Flow Overview

1. **Pet Owner** can create a chat request to their connected clinic
2. **Vet/Receptionist** sees pending requests and can accept them
3. **Staff** can also proactively start chats with patients
4. Messages support: text, images, videos, files, voice messages
5. Read receipts: sent → delivered → read

### Chat Request Flow

```
Pet Owner creates request
    ↓
ChatRoom created with:
  - status: pending
  - vetId: '' (empty)
    ↓
Appears in clinic's pending requests
    ↓
Vet/Receptionist accepts:
  - status: active
  - vetId: assigned staff ID
    ↓
Active chat between pet owner and staff
```

### Message Status Flow

```
User sends message → status: sent (single check ✓)
    ↓
Recipient's app syncs → status: delivered (double check ✓✓ gray)
    ↓
Recipient opens chat → status: read (double check ✓✓ blue)
```

### Typing Indicators

Uses Firebase Realtime Database for real-time typing status:

```dart
// Setting typing status
await _database.ref('typing/$chatRoomId/$userId').set({
  'isTyping': true,
  'timestamp': rtdb.ServerValue.timestamp,
});

// Listening to other user's typing
_database.ref('typing/$chatRoomId/$otherUserId').onValue.listen((event) {
  // Check isTyping and timestamp (auto-expire after 3s)
});
```

### Message Pagination

Messages are fetched in pages of 50, newest first, then reversed for display:

```dart
// Initial load
_chatService.getMessages(chatRoomId, limit: 50);

// Load more (pagination)
_chatService.getOlderMessages(chatRoomId, beforeTimestamp: oldestMessage.timestamp);
```

### UI Freeze Feature

Prevents message updates from disrupting user while scrolling:

```dart
// When user scrolls up
chatProvider.freezeUI();

// Frozen messages returned instead of live updates
List<ChatMessage> get currentMessages {
  if (_uiFrozen && _frozenMessages != null) {
    return _frozenMessages!;
  }
  return _currentMessages;
}

// Badge shows count of new messages while frozen
int get pendingMessageCount => _newMessageIds.length;

// When user returns to bottom
chatProvider.unfreezeUI();
```

---

## 14. Appointment Request System

Pet owners can request appointments with their connected clinic. Receptionists manage these requests.

### Appointment Request Model

```dart
enum AppointmentRequestStatus {
  pending,    // 0 - Awaiting clinic response
  confirmed,  // 1 - Appointment confirmed
  denied,     // 2 - Request denied by clinic
  cancelled   // 3 - Cancelled by pet owner
}

enum TimePreference {
  morning,    // 0 - Morning (8am-12pm)
  afternoon,  // 1 - Afternoon (12pm-5pm)
  evening,    // 2 - Evening (5pm-8pm)
  anytime     // 3 - Flexible
}

class AppointmentRequest {
  final String id;
  final String clinicId;
  final String petOwnerId;
  final String petOwnerName;
  final String petId;
  final String petName;
  final String? petSpecies;
  final DateTime preferredDateStart;
  final DateTime preferredDateEnd;
  final TimePreference timePreference;
  final String reason;
  final String? notes;
  final AppointmentRequestStatus status;
  final String? handledBy;
  final String? handledByName;
  final DateTime? handledAt;
  final String? responseMessage;
  final String? linkedChatRoomId;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

### Appointment Request Flow

```
Pet Owner creates request (ClinicPage → AppointmentRequestForm)
    ↓
Request stored in Firestore: /appointmentRequests/{requestId}
  - status: pending
  - clinicId, petOwnerId, petId, dates, reason, etc.
    ↓
Receptionist sees in ReceptionistClinicPage (Appointments filter)
    ↓
Receptionist can:
  - Confirm: status → confirmed, optional message
  - Deny: status → denied, required reason message
  - Chat: Creates/opens chat with pet owner, links to request
    ↓
Pet Owner sees status update in their ClinicPage
```

### Service Methods

```dart
class AppointmentRequestService {
  // Create new request (pet owner)
  Future<String> createRequest({...});
  
  // Streams for real-time updates
  Stream<List<AppointmentRequest>> clinicPendingRequestsStream(clinicId);
  Stream<List<AppointmentRequest>> clinicAllRequestsStream(clinicId);
  Stream<List<AppointmentRequest>> petOwnerRequestsStream(petOwnerId);
  
  // Staff actions
  Future<void> confirmRequest({requestId, handledBy, handledByName, message});
  Future<void> denyRequest({requestId, handledBy, handledByName, message});
  
  // Pet owner actions
  Future<void> cancelRequest(requestId);
  
  // Link chat room to request
  Future<void> linkChatRoom({requestId, chatRoomId});
}
```

### Provider State

```dart
class AppointmentRequestProvider extends ChangeNotifier {
  List<AppointmentRequest> get pendingRequests;  // Pending only (receptionist)
  List<AppointmentRequest> get allRequests;      // All statuses (receptionist)
  List<AppointmentRequest> get myRequests;       // Pet owner's requests
  int get pendingCount;
  
  // Initialize based on role
  void initializeForReceptionist(clinicId);
  void initializeForPetOwner(petOwnerId);
}
```

---

## 15. Media Handling

### Media Types

```dart
enum MediaType { image, video, file, voice }
```

### Upload Configuration

```dart
class MediaConfig {
  static const int maxImageSizeBytes = 10 * 1024 * 1024;     // 10MB
  static const int maxVideoSizeBytes = 50 * 1024 * 1024;     // 50MB
  static const int maxFileSizeBytes = 25 * 1024 * 1024;      // 25MB
  static const int maxVoiceDuration = 60;                     // seconds
  static const int imageQuality = 70;                         // compression %
  static const int thumbnailSize = 200;                       // pixels
}
```

### Media Upload Flow

```
User picks/records media
    ↓
MediaService validates size/type
    ↓
Image/video compressed if needed
    ↓
Upload to Firebase Storage with progress callback
    ↓
Generate thumbnail (for images/videos)
    ↓
ChatService.sendMessage with mediaUrl, thumbnailUrl, etc.
```

### Voice Recording

```dart
// Start recording
await chatProvider.startVoiceRecording();

// Recording timer updates _recordingDuration

// Stop and send
await chatProvider.stopAndSendVoiceRecording();

// Or cancel
await chatProvider.cancelVoiceRecording();
```

### Media Caching

`MediaCacheService` handles local caching of downloaded media:

```dart
await MediaCacheService.instance.init();

// Cache paths
final cachePath = await MediaCacheService.instance.getCachedPath(url);
```

---

## 16. Push Notifications

### FCM Token Management

```dart
class PushNotificationService {
  Future<void> initialize() async {
    // Request permissions (iOS)
    await FirebaseMessaging.instance.requestPermission();

    // Get token
    final token = await FirebaseMessaging.instance.getToken();

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      // Update in Firestore
    });
  }

  Future<void> saveTokenForUser(String userId) async {
    // Store token in users/{userId}.fcmToken
  }

  Future<void> clearTokenForUser(String userId) async {
    // Remove token on logout
  }
}
```

### Token Storage

FCM tokens stored in user profile:

```
/users/{userId}
├── fcmToken: "device_token_string"
└── ...
```

### Notification Handling

Cloud Functions (in `functions/`) listen to message creation and send FCM notifications to the other participant.

---

## 17. Security Rules

### Key Principles

1. **Users own their data:** Read/write own user doc and subcollections
2. **Clinic isolation:** Members can only access their clinic's data
3. **Temp profile support:** Special handling for invite placeholder profiles
4. **Chat participant access:** Only petOwnerId or vetId can access room/messages
5. **App owner override:** Global admin access

### Rule Highlights

```javascript
// User can read/write their own data
match /users/{userId} {
  allow read, write: if request.auth.uid == userId;
}

// Clinic admins can manage their clinic
match /clinics/{clinicId} {
  allow update: if isClinicAdmin(clinicId) || isAppOwner();
}

// Chat room access
match /chatRooms/{chatRoomId} {
  allow read, write: if
    resource.data.petOwnerId == request.auth.uid ||
    resource.data.vetId == request.auth.uid;
}

// Clinic members can accept pending requests
allow update: if
  resource.data.status == 0 && // pending
  isClinicMember(resource.data.clinicId);
```

### Enum Indices Reference

```javascript
// UserType: petOwner=0, vet=1, clinicAdmin=2, appOwner=3, receptionist=4
// ClinicRole: admin=0, vet=1, receptionist=2
// ChatRoomStatus: pending=0, active=1, closed=2
// MessageStatus: sent=0, delivered=1, read=2
```

---

## 18. Feature Summary by Role

### Pet Owner Features

- **Dashboard:** Pet info, quick stats, upcoming events
- **Pets:** Add/edit pets, track symptoms, view history
- **Calendar:** Appointments, medications, notes with recurrence
- **Chat:** Request conversations with clinic, real-time messaging
- **Profile/Settings:** Account management, clinic connection

### Vet Features

- **Dashboard:** Patient overview, pending requests
- **Patients:** View connected pet owners and their pets
- **Chat:** Accept requests, message pet owners, view pet info
- **Proactive Outreach:** Start chats with patients

### Clinic Admin Features

- All vet features, plus:
- **Staff Management:** Invite/manage vets and receptionists
- **Clinic Settings:** Update clinic info, business hours
- **Overview:** All clinic chats and activity

### Receptionist Features

- **Dashboard:** Overview with pending counts, quick actions, messages section
- **Patients:** View connected pet owners and their pets
- **Clinic Tab (Unified Communications):**
  - Combined feed of chat requests, active chats, and appointment requests
  - Filter by All/Chats/Appointments with badge counts
  - Accept pending chat requests
  - Confirm/Deny appointment requests with messages
  - Open chat with pet owners directly from appointment requests
  - Search across all communications

### App Owner Features

- **Admin Dashboard:** Create clinics, assign clinic admins
- **Global Overview:** View all clinics and activity
- **Support Tools:** Manage system-wide settings

---

## Appendix A: File Naming Conventions

| Type      | Convention                 | Example               |
| --------- | -------------------------- | --------------------- |
| Pages     | `snake_case_page.dart`     | `dashboard_page.dart` |
| Widgets   | `snake_case_widget.dart`   | `info_card.dart`      |
| Models    | `snake_case_model.dart`    | `clinic_models.dart`  |
| Services  | `snake_case_service.dart`  | `chat_service.dart`   |
| Providers | `snake_case_provider.dart` | `user_provider.dart`  |

## Appendix B: Firestore Indexes

Required composite indexes for queries:

```json
{
  "indexes": [
    {
      "collectionGroup": "chatRooms",
      "fields": [
        { "fieldPath": "vetId", "order": "ASCENDING" },
        { "fieldPath": "isActive", "order": "ASCENDING" },
        { "fieldPath": "updatedAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "chatRooms",
      "fields": [
        { "fieldPath": "petOwnerId", "order": "ASCENDING" },
        { "fieldPath": "isActive", "order": "ASCENDING" },
        { "fieldPath": "updatedAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "chatRooms",
      "fields": [
        { "fieldPath": "clinicId", "order": "ASCENDING" },
        { "fieldPath": "isActive", "order": "ASCENDING" },
        { "fieldPath": "updatedAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "appointmentRequests",
      "fields": [
        { "fieldPath": "clinicId", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "appointmentRequests",
      "fields": [
        { "fieldPath": "clinicId", "order": "ASCENDING" },
        { "fieldPath": "updatedAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "appointmentRequests",
      "fields": [
        { "fieldPath": "petOwnerId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```

---

> This documentation should be kept in sync with the codebase. When making significant architectural changes, update the relevant sections.
