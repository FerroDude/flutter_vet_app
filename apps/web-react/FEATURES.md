# Yoshi Vet Care web — feature register

What the React app in `apps/web-react` does. Shared types and medication math live in `packages/shared`.

## Product

One vet and her clients. A client profile stores `vetId` (the vet's uid); one client belongs to one vet. There are no clinics, receptionists or app owners.

The UI is European Portuguese (`pt-PT`), written directly in the components.

## Accounts

- No sign-up in the app. Firestore rules refuse self-created profiles.
- Vets are created with `npm run create-vet` (Admin SDK, see `scripts/create-vet.mjs`).
- The vet adds a client (Clientes → Adicionar cliente). That creates the Auth user with a random password, writes the profile with `vetId`, sends the set-password email and opens their chat room.
- Login screen: email + password, and "forgot password". No email-verification step.

`RootGate`:

| State | Screen |
|---|---|
| Firebase env missing | Setup message |
| Signed out | `AuthScreen` |
| No profile / unknown role / load error | "Sem acesso" with retry + sign out |
| Vet without a display name | `DisplayNameScreen` |
| Vet | `VetApp` |
| Client | `ClientApp` |

## Client app (`ClientApp`)

Menu: Painel · Animais · Agenda · Chat · Perfil.

- **Painel**: greeting, unread messages, upcoming appointments (next 3), up to 3 active medications, today's entries. Pets live only in the Animais tab.
- **Animais**: pet list and search; pet form (create/edit); pet page with record, medications (log/undo dose, pause, complete, delete), appointments and symptoms.
- **Agenda**: appointment requests (pending ones can be cancelled; answers from the last 30 days stay visible), month calendar, the selected day (medication doses, events, symptoms) and upcoming appointments. "Pedir marcação" asks the vet for a visit; "Adicionar" adds a reminder, a medication or a symptom. Each appointment opens its own page (`agenda/consultas/:id`); for vet-booked ones the client can cancel once, with a mandatory reason — the vet is notified in chat.
- **Chat**: the single conversation with the vet (text, photos/videos/files, voice, replies, reactions, delete own message).
- **Perfil**: name, phone, address; the vet's contact details; sign out.

Appointments the vet booked are read-only for the client, except a one-shot cancellation with a reason.

## Vet app (`VetApp`)

Menu: Painel · Agenda (badge = pending requests) · Clientes · Chat · Perfil.

- **Painel**: pending requests, unread messages, client count, upcoming appointments, and "Canceladas recentemente" (client cancellations from the last 7 days, with the reason).
- **Agenda**: pending requests (confirm with a time → booked into the client's calendar in one batch; deny with a reason; open chat), month calendar with appointment counts, the selected day (client-cancelled appointments shown struck through and removable), and the handled-requests history. "Nova consulta" books an appointment for any client/pet (warns about clashes within 30 minutes); edit and cancel from the list.
- **Clientes**: list and search; add client. Client page: contact details, chat, book appointment, upcoming appointments, pets (open a pet page or add a pet).
- **Pet page (vet view)**: everything the client sees plus **private notes** (a list of notes only the vet can read) and booking appointments directly.
- **Chat**: conversation list + open conversation.
- **Perfil**: name, phone, address (clients see it for home visits); sign out.

## Data (Firestore)

| Path | What |
|---|---|
| `users/{uid}` | Profile. `userType` 0 client / 1 vet, `vetId` on clients |
| `users/{uid}/pets/{petId}` | Pet; `medications/`, `symptoms/` below it |
| `users/{uid}/pets/{petId}/private/{noteId}` | Vet-only notes |
| `users/{uid}/events/{eventId}` | Calendar entries. Vet bookings carry `bookedByVetId`, `clientName`, `petName` |
| `appointmentRequests/{id}` | Client → vet requests (`vetId`, `status`, `bookedDateTime`) |
| `chatRooms/{id}` + `messages/` | One room per client/vet pair |

The vet agenda is a collection-group query on `events` where `bookedByVetId == vet` (index in `firestore.indexes.json`).

## Not in the app

- Push notifications: removed until server-side senders exist. The old Cloud Functions were clinic-based and live on the `archive/mobile-flutter` branch. In-app toasts for new chat messages still work.
- Account deletion: not offered; the vet manages client accounts.
