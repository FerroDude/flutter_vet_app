# Multi‑Tenant Vet Clinic System — Overview

This app is a Flutter mobile client using Firebase for authentication and data. It enables pet owners to connect with clinics, manage events, and chat with vets. Content is aligned with the actual implementation under `apps/mobile-flutter`.

## Architecture

- Frontend: Flutter (Dart), Material, Provider (`ChangeNotifier`).
- Backend: Firebase Auth and Cloud Firestore.
- Boot flow: `lib/main.dart` initializes Firebase, local cache, and a placeholder notification service. `core/auth/auth_wrapper.dart` gates by auth + email verification and composes user‑scoped providers.

Providers (created post‑auth):
- `UserProvider`: user profile, roles, clinic linkage.
- `EventProvider`: events and counts via `EventRepository`.
- `ChatProvider`: chat rooms/messages via `ChatService`.

## Roles

- Pet Owner: dashboard, appointments, chat after connecting to a clinic.
- Vet: clinic context required; views patient chats.
- Clinic Admin: manages clinic settings and members.
- App Owner: elevated admin; routed to a separate admin dashboard.

## Firestore Data Model (as implemented)

- Users: `users/{userId}`
  - `clinicHistory`: `users/{userId}/clinicHistory/{historyId}`
  - `events`: `users/{userId}/events/{eventId}`

- Clinics: `clinics/{clinicId}`
  - `members`: `clinics/{clinicId}/members/{userId}` (role, permissions)

- Chat: `chatRooms/{chatRoomId}`
  - `messages`: `chatRooms/{chatRoomId}/messages/{messageId}`
  - Fields: `clinicId`, `petOwnerId`, `vetId`, `unreadCounts`, `lastMessage`, `isActive`.

Notes:
- No participants array or presence tracking in code.
- Events are fetched with queries; not streaming from snapshots.

## Key Features

- Email/password authentication with email verification.
- Clinic discovery (reads `clinics` where `isActive == true`), creation (admin/app owner), and member management.
- Events: appointments, medications, notes; counts and filtering.
- Chat: 1:1 pet owner ↔ vet with unread counters and simple message types.
- Theming: centralized in `lib/theme` with persisted `ThemeManager`.

## Current Limitations

- Local notifications are placeholders; no real scheduling.
- Event list caching disabled pending serialization fix (counts caching enabled).
- No presence/multi‑participant chat features.
- `main.dart` contains large UI blocks; refactor in progress.

