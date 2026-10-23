# Vet+ web — feature register

Written from the React code in `apps/web-react` on 2026-10-17. This file lists what the web app actually does.

The Flutter app under `apps/mobile-flutter` is deprecated. This file is the feature register for the web app.

Visual rules live in `DESIGN.md`. Shared types, medication math, and the confirm-to-calendar helper live in `packages/shared`.

## Product

A solo vet and her clients. There is no clinic. A client stores `vetId` (the vet's Firebase uid). One client belongs to one vet. A second vet is another user with `userType` vet and her own clients.

The UI is European Portuguese (`pt-PT`). Auth copy is in `src/i18n/en.ts` and loaded as the `pt-PT` bundle. Other screens still mix catalog strings and Portuguese literals.

The set-password email language is the Firebase Auth template in the console. The app does not set it.

## Stack

Vite, React 18, TypeScript, React Router, Tailwind CSS v4, Firebase Auth, Firestore, Storage, and Cloud Messaging.

Tests: `npm test` runs Vitest in `packages/shared` and `apps/web-react`. Firestore rules tests are `npm run test:rules` and need the Firestore emulator (`firebase emulators:exec --only firestore`).

## Who can sign in

Public screens are login and forgot password. There is no open registration. The vet adds a client.

`RootGate` after Firebase Auth loads:

| State | Screen |
|---|---|
| Firebase env missing | Placeholder asking for `.env.local` |
| Signed out | `AuthScreen` |
| Signed in, email not verified | `VerifyEmailScreen` |
| Profile load error | Retry |
| Vet with no display name | `DisplayNameScreen` |
| Role `petOwner` | `PetOwnerApp` |
| Role `vet` | `StaffApp` |
| Anything else | Account is not set up |

A vet is `userType === vet`, with or without a clinic role. Receptionist, clinic admin, and app owner no longer get a shell.

## Vet

Nav: Painel, Clientes, Pedidos, Chat, Perfil.

- Dashboard: unread messages, pending requests, today's confirmed appointments.
- Clients: users whose `vetId` is her uid. Add client by name and email. That creates the Auth user, writes the profile, sends the set-password email, and opens one active chat room.
- Client detail shows phone and address, pets, and a link into the pet record. She can create and edit that client's pets, medications, and symptoms.
- Private notes live at `users/{clientId}/pets/{petId}/private/notes`. Only the vet can read or write them. The client pet page does not load that document.
- Requests: confirm asks for a date and time and writes or updates one event on the client's calendar (`appointmentRequestId`, `bookedByVetId`). Deny still asks for a reason.
- Chat: her active rooms. No pending Accept step for new rooms.
- Profile: she edits the name, phone, and address the client sees.

## Client

Nav: Painel, Animais, Calendário, Marcações, Chat, Perfil.

- Pets, medications, symptoms, and calendar stay. Both the client and the vet can edit pets, medications, and symptoms.
- Chat opens the room created when the vet added them. Route `/chat`. `/clinic` redirects there.
- Appointments require `vetId`. The request stores `vetId` and does not write `clinicId`.
- A vet-booked calendar event stays visible. The client cannot edit or delete it in the UI. Rules also deny that delete.
- Profile shows the vet's name, phone, and address for in-house visits. There is no clinic connect or disconnect.

## Firestore the UI writes

| Path | Used for |
|---|---|
| `users/{uid}` | Profile. Clients have `vetId`. |
| `users/{uid}/pets/{petId}` | Pets |
| `users/{uid}/pets/{petId}/medications` | Medications and dose logs |
| `users/{uid}/pets/{petId}/symptoms` | Symptoms |
| `users/{uid}/pets/{petId}/private/notes` | Vet-only notes |
| `users/{uid}/events` | Calendar, including vet-booked appointments |
| `appointmentRequests` | Requests addressed by `vetId`, plus `calendarEventId` and `bookedDateTime` |
| `chatRooms` and `chatRooms/{id}/messages` | Direct vet–client chat |

Security rules for this model are in the repo-root `firestore.rules`. They are not live until deployed to `vetplus-digital`. Old clinic documents are unused.

## Tests

- `packages/shared`: medication math, `isVet` for a solo vet, and `bookAppointmentFromConfirm` (first confirm creates, second confirm updates the same event).
- `apps/web-react`: auth screen has sign-in and password reset, and no registration form.
- `npm run test:rules`: client pet access, private notes, `vetId` lock, vet address read, and client delete of a vet-booked event.
