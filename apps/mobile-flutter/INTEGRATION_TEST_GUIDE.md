# Integration Test Guide — VetPlus Mobile

Scope reflects the current implementation (Flutter + Firebase) in `apps/mobile-flutter`.

## Pre‑Setup

- Firebase project configured and linked in `lib/firebase_options.dart`.
- Email/Password auth enabled (require email verification).
- Firestore created with rules from `apps/mobile-flutter/firestore.rules`.

Test Accounts:

- Pet Owner: `petowner@test.com` / `password123`
- Clinic Admin: `admin@vetclinic.com` / `password123`
- Vet: `vet@vetclinic.com` / `password123`

## Phase 1 — Authentication & Onboarding

- 1.1 Registration → verify email → login shows AuthWrapper progressing.
- 1.2 Pet Owner flow → ClinicSelection (can search, can skip once) → main app.
- 1.3 Clinic Admin flow → Create clinic → lands on admin dashboard.
- 1.4 Vet flow → cannot access clinic features until added by clinic admin.

Expected: Email verification enforced; unauthenticated state shows `AuthPage`.

## Phase 2 — Clinic Management

- 2.1 Admin dashboard visible for clinic admins.
- 2.2 Update clinic settings (name, address, hours) → persists.
- 2.3 Add vet to clinic (creates member with role vet) → appears in members list.
- 2.4 Pet owner clinic search → reads clinics where `isActive == true` → connect.

## Phase 3 — Chat

- 3.1 Pet owner: Start conversation → chat room created (1:1 with vet).
- 3.2 Clinic staff: sees patient conversations (by vet or by clinic for admins).
- 3.3 Real‑time messages: text messages appear on both sides; unread badges update.

Notes: Attachments, presence, and multi‑participant chats are not implemented yet.

## Phase 4 — Events & Calendar

- 4.1 Create appointment/medication/note → persists under `users/{uid}/events`.
- 4.2 Event counts (today/tomorrow/thisWeek/total) load; list updates after refresh.
- 4.3 Medication completion → next occurrence created if recurring; notifications are placeholders.
- 4.4 Edit/delete event → changes saved and reflected on reload.

## Phase 5 — Cross‑Feature

- 5.1 Role‑based navigation: app owner → admin dashboard; others → main app.
- 5.2 Clinic isolation: users see only their clinic context where applicable.
- 5.3 Persistence across app restarts for chat and events.

## Edge Cases

- Authentication errors (weak passwords, invalid email); unverified email blocked.
- Form validation errors across create/edit flows.
- Network interruptions: user‑friendly errors; retry works post‑reconnect.

## Known Limitations

- Local notifications are no‑ops; scheduling isn’t validated.
- Event list caching is disabled (counts caching works).
- Chat attachments and uploads are not implemented.
