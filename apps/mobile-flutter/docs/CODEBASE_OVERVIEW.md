# Peton Mobile App — Codebase Overview and Analysis

This document summarizes the current Flutter codebase, its architecture, data model, and notable gaps. All statements are verified against the source under `apps/mobile-flutter` as of this analysis.

## Project Overview

- Platform: Flutter mobile (Android/iOS)
- Backend: Firebase (Auth, Firestore). Storage not used yet.
- State management: Provider (`ChangeNotifier`) with service/repository layers.
- Entry point: `apps/mobile-flutter/lib/main.dart:1`

## App Boot & Composition

- `main.dart` initializes Firebase with `firebase_options.dart`, `CacheService.init()`, and a placeholder `NotificationService.initialize()`.
- `MyApp` provides global services and a `ThemeManager` via `MultiProvider`.
- `AuthWrapper` gates the app by Firebase Auth state and email verification, then creates user-scoped providers:
  - `UserProvider` for profile/clinic context
  - `EventProvider` backed by `EventRepository`
  - `ChatProvider` backed by `ChatService`
- After auth, routing is role-aware:
  - App owner → `pages/admin_dashboard.dart`
  - Others → `MyHomePage` (bottom navigation with Dashboard, Pets, Appointments, Chat)

Key files:

- `apps/mobile-flutter/lib/main.dart:1`
- `apps/mobile-flutter/lib/core/auth/auth_wrapper.dart:1`
- `apps/mobile-flutter/lib/core/auth/auth_page.dart:1`
- `apps/mobile-flutter/lib/core/auth/email_verification_page.dart:1`

## Directory Structure (verified)

- `lib/core` — Auth, onboarding, navigation glue (auth already extracted)
- `lib/models` — Data models and services that behave like models (events, clinic, chat, notifications)
- `lib/services` — Firestore-backed services (`ClinicService`, `ChatService`, `CacheService`)
- `lib/repositories` — `EventRepository` (Firestore + caching + streams)
- `lib/providers` — `UserProvider`, `EventProvider`, `ChatProvider`
- `lib/pages` — Larger screens (e.g., admin dashboard, chat)
- `lib/widgets` — Calendar, forms, appointment pages
- `lib/shared/widgets` — Reusable UI pieces (info card, quick action, list placeholder)
- `lib/theme` — Design tokens, theme config, theme manager
- `lib/utils` — Perf utilities

Note: `main.dart` still contains substantial UI (e.g., `MyHomePage`, `DashboardPage`, some Pets UI). Refactor is partially complete.

## Dependencies (pubspec.yaml)

- Firebase: `firebase_core`, `firebase_auth`, `cloud_firestore`
- UI/state: `provider`, `table_calendar`, `intl`
- Local: `shared_preferences`, `uuid`, `timezone`
- Notifications: Not active. `flutter_local_notifications` is commented out due to Android desugaring issues. `NotificationService` is a placeholder.

File: `apps/mobile-flutter/pubspec.yaml:1`

## Data Models & Serialization

All models support Firestore `Timestamp | int(ms) | ISO string` parsing for date fields.

- Events
  - Base: `CalendarEvent` with `EventType { appointment, medication, note }`
  - `AppointmentEvent` (vetName, location, type, isConfirmed, contactInfo)
  - `MedicationEvent` (name, dosage, frequency/custom interval, completion, nextDose, requiresNotification)
  - File: `apps/mobile-flutter/lib/models/event_model.dart:1`

- Chat
  - `ChatMessage` (text/image/appointment/medication), status, timestamp
  - `ChatRoom` (clinicId, petOwnerId/name, vetId/name, petIds[], lastMessage, unreadCounts map)
  - File: `apps/mobile-flutter/lib/models/chat_models.dart:1`

- Clinic & Users
  - `Clinic` (+ businessHours), `ClinicMember` (role, permissions), `UserClinicHistory`
  - `UserProfile` (userType, connectedClinicId, clinicRole, hasSkippedClinicSelection, isActive)
  - File: `apps/mobile-flutter/lib/models/clinic_models.dart:1`

## Firestore Structure (as used by code)

- Users
  - `users/{userId}` — user profile
  - `users/{userId}/clinicHistory/{historyId}` — join/leave records
  - `users/{userId}/events/{eventId}` — appointments/medications/notes
  - Source: `ClinicService`, `EventRepository._getEventsCollection()`

- Clinics
  - `clinics/{clinicId}` — clinic info (adminId, contact, hours)
  - `clinics/{clinicId}/members/{userId}` — `ClinicMember`
  - Source: `ClinicService`

- Chat
  - `chatRooms/{chatRoomId}` — single pet owner ↔ single vet (no participants array)
  - `chatRooms/{chatRoomId}/messages/{messageId}` — messages
  - Source: `ChatService`

Contrasts with existing docs:

- Docs mention `/events/{userId}/events/{eventId}` — actual path is `/users/{userId}/events/{eventId}`.
- Docs mention `/clinicMembers/{clinicId}/members/...` — actual path is `/clinics/{clinicId}/members/...`.
- Docs mention `chatRooms` with a `participants` array and a `participants` subcollection — current code does not use those. Access control should be derived from `petOwnerId` and `vetId` instead.

## Services, Repositories, and Providers

- EventRepository
  - Streams: events and counts for reactive UI
  - Fetch with Firestore query filters and order by `dateTime`
  - Caching: Intended via `CacheService` but event list caching is currently disabled (serialization TODO)
  - Offline: queues offline edits in SharedPreferences
  - Paths: `users/{userId}/events`
  - File: `apps/mobile-flutter/lib/repositories/event_repository.dart:1`

- CacheService
  - Stores event counts and offline items in SharedPreferences
  - `cacheEvents(...)` intentionally no-ops (disabled) pending fix for `Timestamp` serialization
  - File: `apps/mobile-flutter/lib/services/cache_service.dart:1`

- ClinicService
  - CRUD for clinics and members; user–clinic connect/disconnect; search clinics
  - Paths: `clinics/{clinicId}` with `members` subcollection; `users/{userId}` with `clinicHistory`
  - File: `apps/mobile-flutter/lib/services/clinic_service.dart:1`

- ChatService
  - One-on-one chat creation and lookups; messages CRUD; mark read
  - Streams: vet/clinic/petOwner chatRooms and messages
  - Unread counts kept in `ChatRoom.unreadCounts` (map of `userId -> count`)
  - File: `apps/mobile-flutter/lib/services/chat_service.dart:1`

- Providers
  - `UserProvider`: Loads/creates profiles, handles clinic linking, role checks; elevates to app owner by email allowlist (`pedroferrodude@hotmail.com`). File: `apps/mobile-flutter/lib/providers/user_provider.dart:1`
  - `EventProvider`: Coordinates event loading/streams and schedules notifications. File: `apps/mobile-flutter/lib/providers/event_provider.dart:1`
  - `ChatProvider`: Coordinates chat rooms/messages, streams, send actions, and unread badge aggregation. File: `apps/mobile-flutter/lib/providers/chat_provider.dart:1`

## Theming

- `AppTheme` centralizes colors, type scale, and component styles
- `ThemeManager` persists theme mode via SharedPreferences; exposes toggle
- Files: `apps/mobile-flutter/lib/theme/app_theme.dart:1`, `apps/mobile-flutter/lib/theme/theme_manager.dart:1`

## Feature Summary

- Authentication: Email/password with enforced email verification
- Clinic management: Create clinic (admin/app owner), manage members, search/connect
- Calendar & events: Appointments/medications/notes with filtering and counts
- Chat: One-on-one pet owner ↔ vet rooms with unread counts and simple types
- Admin (App Owner): Dedicated dashboard page exists; implementation is large

## Gaps, Placeholders, and TODOs (important)

- Notifications: `NotificationService` is a stub; no actual local notifications are scheduled.
- Event caching: Disabled in `CacheService.cacheEvents` pending date serialization fix; counts caching is enabled.
- Main refactor: `main.dart` still contains large UI blocks (e.g., Dashboard); refactor plan in `REFACTOR.md` is only partially executed.
- Multi-participant chat: Not implemented; current schema is strictly 1:1 (pet owner ↔ vet).
- Presence/status tracking: Not implemented; docs claim presence but code has no such feature.
- Images/storage: `ChatMessage.imageUrl` exists but no Storage integration or upload flows are implemented.
- Security rules: Existing docs reference structures not used by code (see below).
- Docs encoding: `SYSTEM_OVERVIEW.md`, `DEPLOYMENT_GUIDE.md`, `INTEGRATION_TEST_GUIDE.md`, and `REFACTOR.md` contain encoding artifacts and several inaccuracies.

## Doc Accuracy Audit (key mismatches)

- SYSTEM_OVERVIEW.md
  - Claims multi-participant chat and presence tracking. Not present in code.
  - General architecture and role descriptions are directionally correct.

- DEPLOYMENT_GUIDE.md
  - Firestore paths listed for events and clinic members do not match actual code paths (see “Firestore Structure”).
  - Security rules use a `participants` array and subcollection which the code does not maintain.

- INTEGRATION_TEST_GUIDE.md
  - Step flows reference features like sharing appointments/medications in chat and attachments. Message types exist, but UI flows for sharing and uploads aren’t implemented in the current pages.

- REFACTOR.md
  - States “Next target: extract authentication components” but auth pages are already extracted. The overall refactor remains partial; `main.dart` is still very large.

## Suggested Security Rules (to fit current schema)

High-level guidance only; adapt to your needs:

- Allow a user to read/write their doc and owned subcollections:
  - `match /users/{userId} { allow read, write: if request.auth != null && request.auth.uid == userId }`
  - `match /users/{userId}/events/{eventId} { allow read, write: if request.auth != null && request.auth.uid == userId }`
  - `match /users/{userId}/clinicHistory/{historyId} { allow read, write: if request.auth != null && request.auth.uid == userId }`

- Clinics:
  - `match /clinics/{clinicId} { allow read: if isClinicMember(clinicId); allow write: if isClinicAdmin(clinicId) }`
  - `match /clinics/{clinicId}/members/{userId} { allow read: if isClinicMember(clinicId); allow write: if isClinicAdmin(clinicId) }`

- Chat (1:1 rooms):
  - `match /chatRooms/{chatRoomId} { allow read, write: if request.auth != null && (request.auth.uid == resource.data.petOwnerId || request.auth.uid == resource.data.vetId) }`
  - `match /chatRooms/{chatRoomId}/messages/{messageId} { allow read, write: if request.auth != null && (request.auth.uid == get(/databases/$(database)/documents/chatRooms/$(chatRoomId)).data.petOwnerId || request.auth.uid == get(/databases/$(database)/documents/chatRooms/$(chatRoomId)).data.vetId) }`

Helper functions `isClinicMember` and `isClinicAdmin` can consult `clinics/{clinicId}/members/{userId}`.

## Recommended Next Steps

- Notifications: Choose a supported plugin (e.g., `awesome_notifications`) and wire `NotificationService` methods.
- Caching: Fix serialization (store numeric epoch timestamps only) and re-enable `CacheService.cacheEvents`.
- Refactor: Continue extracting `main.dart` pages/widgets into `lib/pages` and `lib/features` per the plan.
- Docs: Re-encode/replace corrupted Markdown and align Firestore paths/rules with the implemented schema.
- Storage: Implement image/file uploads for chat if required by product scope.
- Presence: If needed, design presence with Realtime Database or Firestore + functions.

---

This overview will be kept as the source of truth for future development context.

