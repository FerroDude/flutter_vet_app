# Vet+ web — feature register

Written from the React code in `apps/web-react` on 2026-10-17. This file lists what the web app actually does. It is not a roadmap.

The Flutter app under `apps/mobile-flutter` is deprecated. This file is the feature register for the web app.

Visual rules live in `DESIGN.md`. Shared types and medication math live in `packages/shared`.

## Stack

Vite, React 18, TypeScript, React Router, Tailwind CSS v4, Firebase Auth, Firestore, Storage, and Cloud Messaging. English UI. Auth screens use `react-i18next` (`src/i18n/en.ts`). Most other screens use hardcoded English strings.

## Who can sign in

`RootGate` decides the screen after Firebase Auth loads.

| State | Screen |
|---|---|
| Firebase env missing | Placeholder telling you to fill `.env.local` |
| Signed out | `AuthScreen` |
| Signed in, email not verified | `VerifyEmailScreen` |
| Profile load error | Retry |
| Vet or receptionist with no display name | `DisplayNameScreen` |
| Pet owner with no clinic and selection not skipped | `ClinicSelectionScreen` |
| Role `petOwner` | `PetOwnerApp` |
| Role `receptionist`, `vet`, or `clinicAdmin` | `StaffApp` |
| Role `appOwner` | `AppOwnerApp` |
| Anything else | "account isn't set up" placeholder |

Role comes from the Firestore user profile, in this order: app owner, clinic admin, vet, receptionist, pet owner. A signed-in user with a verified email also gets a foreground FCM listener and a silent push-token refresh (`src/lib/messaging.ts`).

### Auth screens

- Log in with email and password
- Create account (name, email, password, confirm)
- Forgot password (Firebase reset email)
- Verify email: resend, poll until verified
- First-login display name for vet and receptionist
- Clinic search, connect, or skip (pet owner only, before home)

Staff invites use a secondary Firebase app to create the Auth user and send a password-reset email (`provisionAuthAccountAndSendReset` in `src/lib/clinicService.ts`).

## Everyone, after login

`AppLayout`: desktop sidebar, mobile bottom nav, skip link, sign out.

`ProfileSettingsPage` (`/profile` on every role):

- Edit display name, phone, address
- Theme: light, dark, or system (`src/lib/theme.ts`, stored in `localStorage` key `vetplus-theme`)
- Browser push: enable or disable. Unsupported and blocked states are shown
- Sign out
- Delete account (cascades the user doc)

Pet owners also see pet / medication / symptom counts and can connect, change, or disconnect a clinic.

## Pet owner

Nav: Dashboard, Pets, Calendar, Appointments, Chat, Profile.

### Dashboard (`/`)

- Greeting plus today's date
- Unread clinic messages, linking to Chat
- Pet cards (photo if `photoUrl` exists, otherwise a name initial). Link to the pet
- Up to three active medications, with log dose, undo, status change
- Today's calendar events

### Pets

- List and search by name, species, or breed (`/pets`)
- Create and edit (`/pets/new`, `/pets/:petId/edit`): name, species, breed, gender, date of birth, weight, color, microchip, veterinarian, medical notes, emergency contact
- The form does not upload a photo. Existing `photoUrl` values still render
- Detail (`/pets/:petId`): edit, delete pet (also deletes that pet's events), medications, appointments, symptoms
- Medications: create, edit, delete, pause, resume, complete, log a dose, undo last dose
- Symptoms: add and delete
- Appointments on the pet: listed from the owner's calendar events

### Calendar (`/calendar`)

Four views: month calendar, appointments, medications, symptoms.

From the calendar you can add an appointment or a note, add a medication, or add a symptom, and pick which pet it belongs to. Day panel shows that day's medications (log dose), events (complete, edit, delete), and symptoms. Month navigation and "today" are included.

Event types the form edits directly: appointment and note. Medication and symptom rows come from those collections, not from a generic event type.

### Appointments (`/appointments`)

Requires a connected clinic. Pet owner creates a request (pet, date range, time preference, reason). Lists pending and handled requests. Can cancel a pending request, which deletes the document.

### Chat (`/clinic`)

Requires a connected clinic. Create a pending chat request (title, optional description). Open a room.

Inside a room (`Conversation`):

- Text, image, video, PDF, and voice messages
- Read ticks (sent, delivered, read)
- Reply, with a quote and jump-to-original
- Emoji reactions: 👍 ❤️ 😂 😮 😢 😡
- Copy text
- Soft-delete your own message
- Pending rooms can still be written in before the clinic accepts

Not in the web UI: in-chat search, multi-select delete, swipe-to-reply.

## Clinic staff

Same shell, different nav.

| Role | Nav | Home |
|---|---|---|
| Receptionist | Dashboard, Requests, Patients, Chat, Profile | `StaffDashboard` with the requests card |
| Vet | Dashboard, Patients, Chat, Profile | `StaffDashboard` without the requests card |
| Clinic admin | Dashboard, Staff, Patients, Chat, Settings, Profile | `AdminDashboard` |

Vets and receptionists must set a display name before this shell loads.

### Receptionist and vet dashboard

Date greeting, clinic name. Cards for messages (unread, plus pending chat count) and patients. Receptionists also get pending appointment-request count. "Today's appointments" lists confirmed requests whose preferred range includes today.

### Appointment requests (`/requests`, receptionist only)

Pending and handled tabs. Confirm or deny with a response message. Open or create the linked 1:1 chat with the pet owner.

### Patients (`/patients`, `/patients/:ownerId`)

Pet owners connected to this clinic only (`userType == petOwner`). Search. Detail shows contact info, pets, recent symptoms per pet, and a button to message the owner (find or create a 1:1 room).

### Chat (`/chat`)

Pending clinic requests with Accept. Assigned active rooms. Same conversation tools as the pet owner, with the staff sender role.

### Clinic admin

Dashboard: clinic name, description, contact, shortcuts to staff, patients, messages, settings.

Staff (`/staff`): switch between veterinarians and receptionists. List active members and remove them. List pending invites. Invite by name and email, resend, or revoke.

Settings (`/settings`): edit name, address, phone, email, website, description, and per-day open/closed hours.

## App owner

Nav: Dashboard, Clinics, Analytics, Profile.

- Dashboard: active clinic count, registered user count (temp invite profiles excluded), recent clinics, shortcuts
- Clinics (`/clinics`): search, create a clinic plus its admin (clinic fields and admin name/email), delete a clinic
- Analytics (`/stats`): total and active clinics; user counts for pet owners, vets, receptionists, clinic admins, and app owners

## Firestore the UI writes

| Path | Used for |
|---|---|
| `users/{uid}` | Profile, clinic link, FCM token, theme is local only |
| `users/{uid}/pets/{petId}` | Pets |
| `users/{uid}/pets/{petId}/medications` | Medications and dose logs |
| `users/{uid}/pets/{petId}/symptoms` | Symptoms |
| `users/{uid}/events` | Calendar appointments and notes |
| `appointmentRequests` | Owner requests, staff confirm/deny |
| `chatRooms` and `chatRooms/{id}/messages` | Chat, replies, reactions, soft delete |
| `clinics` | Clinic profile, hours, create/delete |
| Clinic members and invites | Staff invite, revoke, remove |

Storage paths for chat files: `chats/{roomId}/media/{senderId}/...` and `chats/{roomId}/voice/{senderId}/...`.

Security rules are the ones already deployed for this Firebase project. This app does not ship a new rules file.
