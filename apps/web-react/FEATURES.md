# VetTempo web — feature register

What the React app in `apps/web-react` does. Shared types and medication math live in `packages/shared`.

## Product

VetTempo is a multi-clinic platform. A clinic (`clinics/{id}`) has staff members with role `owner` or `vet` (an owner is also a vet) and linked clients. Staff can belong to several clinics and clients can be linked to several. All clinic staff share the clinic's clients and their pets/meds/symptoms; private and public notes are per clinic. Chats and appointment requests are assigned to one vet — "any vet" goes to the pool where every vet of the clinic sees it and the first to claim it keeps it; the assigned vet can pass it back to the clinic.

**Branding**: VetTempo is the platform shell (login, error/gate screens, public QR pet page, favicon, fonts, neutrals). Inside the signed-in apps the active clinic's `brand` doc applies (`useBrand`), with the clinic logo or its name as text when no logo exists.

The UI is available in European Portuguese (`pt-PT`) and English (`en`), chosen per device on the login screen (PT | EN) or in Profile → Language; switching reloads the app.

## Accounts

- No sign-up in the app. Firestore rules refuse self-created profiles.
- Vets are created with `npm run create-vet` (Admin SDK, see `scripts/create-vet.mjs`).
- Clinic staff adds a client (Clientes → Adicionar cliente) via the `addClinicClient` callable, which writes the profile plus the `clinics/{c}/clients/{uid}` link. Email is optional: with it, the Auth user is created with a random password and the link is active; if the email already has a VetTempo client account the link stays `pending` until the client accepts (a "Pedidos de ligação pendentes" list shows on the clients page); without it the profile gets `invitePending` ("Sem email" badge). "Adicionar email" on the client page calls `createClientLogin`, which creates the Auth user with the same uid so nothing migrates. The "Enviar convite por email agora" checkbox (on by default) sends the set-password email; a "Por convidar" badge shows until the invite is sent — from there staff sends it (button on the client page, also "Reenviar email de acesso"). If the client signs in anyway (e.g. via "forgot password"), their profile clears the flag itself.
- Clinic members are created/deactivated by owners via `createClinicVet` / `updateClinicMember`. Deactivating a vet returns their rooms and pending requests of that clinic to the pool; the last active owner can't be removed.
- Login screen: email + password, and "forgot password". No email-verification step.

`RootGate`:

| State | Screen |
|---|---|
| Firebase env missing | Setup message |
| Signed out | `AuthScreen` |
| No profile / unknown role / load error | "Sem acesso" with retry + sign out |
| Vet without a display name | `DisplayNameScreen` |
| Staff with no clinic | "Sem clínica" with sign out |
| Staff with several clinics (no remembered choice) | Clinic picker, then `VetApp` |
| Staff | `VetApp` |
| Client with several clinics (no remembered choice) | Clinic picker, then `ClientApp` |
| Client | `ClientApp` (works with zero clinics; chat/"Pedir marcação" hidden) |

The active clinic lives in `ClinicProvider` + `localStorage` (`vettempo-clinic`); a switcher sits under the sidebar logo and in Profile on mobile.

## Client app (`ClientApp`)

Menu: Painel · Animais · Agenda · Chat · Perfil.

- **Painel**: greeting, unread messages, upcoming appointments (next 3), up to 3 active medications, today's entries. Pets live only in the Animais tab.
- **Animais**: pet list and search; pet form (create/edit — the birth-date field shows the live age; optional "Esterilizado" flag); pet page with record (birth date shown with age), medications (log/undo dose, past-dose history editor, pause, complete, delete), appointments and symptoms. Public notes written by the vet appear above the record, read-only. Each pet can have a printable QR tag (`/t/:petId`) that opens a public page (photo, name, species/breed, microchip — owner name/phone only when the owner opts in) for anyone who scans it; a "found this pet?" form alerts the owner (dashboard card + notification) without an account — owner/vet get redirected to the in-app pet page instead.
- **Agenda**: appointment requests (pending ones can be cancelled; answers from the last 30 days stay visible), month calendar, the selected day (medication doses, events, symptoms) and upcoming appointments. "Pedir marcação" asks the vet for a visit (date interval + time of day); the vet confirms only inside that requested window; a confirmation alerts the client ("Consulta confirmada") and sends a chat message. "Adicionar" adds a reminder, a medication or a symptom. Each appointment opens its own page (`agenda/consultas/:id`); for vet-booked ones the client can cancel once, with a mandatory reason — the vet is notified in chat. Upcoming appointments offer an "Adicionar ao calendário" menu (Google Calendar link for gmail addresses, a `.ics` download for everyone).
- **Chat**: rooms of the active clinic — one opens directly, several get a simple list (pool rooms show "À espera de um veterinário"), and none offers "Iniciar conversa", which creates a pool room ("any vet"). Clients can already write in pool rooms.
- **Perfil**: name and the full optional contact block (phone, phone 2, address, postal code, country, NIF — editable by the client and by the clinic staff); the active clinic's name and contact details (hidden when the clinic has none); browser-notification permission; sign out. Two independent per-device switches live under Notificações: in-app alert toasts and OS notifications.

While the app is open, the client also gets a toast (+ OS notification when permitted and unmuted) when the vet adds a public note to a pet or books/reschedules an appointment.

Appointments the vet booked are read-only for the client, except a one-shot cancellation with a reason. The vet gets a dedicated "Consulta cancelada" alert (toast + OS notification) on top of the chat message.

## Vet app (`VetApp`)

Menu: Painel · Agenda (badge = pending requests) · Clientes · Chat · Perfil.

- **Painel**: pending requests, unread messages, client count, upcoming appointments, and "Canceladas recentemente" (client cancellations from the last 7 days, with the reason).
- **Agenda**: the clinic's pending requests — pool rows are tagged "Qualquer veterinário", rows assigned to me "Para si" with a "Passar à clínica" action that returns them to the pool. Confirm claims a pool request for me (one transaction books the event into the client's calendar and assigns it; a second vet racing loses), deny needs a reason, chat opens a room. Month calendar, the selected day (client-cancelled appointments shown struck through and removable), and my handled-requests history. A scope select filters "Os meus" (default) / "Todos" / each active vet; rows show the vet's name outside "Os meus". "Nova consulta" books an appointment for any client/pet with a "Veterinário" select (hidden with a single member; the 30-minute clash warning only compares with the assigned vet's appointments); edit and cancel from the list. Each non-cancelled appointment also has the "Adicionar ao calendário" menu.
- **Clientes**: list and search; add client (with or without sending the invite email). Client page: contact details (with "Editar dados" for the optional phone/address/country/NIF fields), chat, book appointment, send/resend the access invite, upcoming appointments, pets (open a pet page or add a pet).
- **Pet page (vet view)**: everything the client sees plus **private notes** (a list of notes only the vet can read) and **public notes** (notes the vet writes and the owner reads on their pet page), and booking appointments directly.
- **Chat**: conversation list (searchable by client name, accent-insensitive) + open conversation. A "Por atribuir" section lists pool rooms; inside one, staff see the messages read-only with an "Aceitar conversa" banner that claims it (a race loser sees "{name} já aceitou esta conversa"). From an assigned conversation "Passar à clínica" returns it to the pool. Messages to a vet-less room count under `unreadCounts.pool` so every vet of the clinic gets the badge.
- **Perfil**: name, phone, address (clients see it for home visits); browser-notification permission; sign out. Two independent per-device switches live under Notificações: in-app alert toasts and OS notifications.

**Google Calendar sync** (opt-in, configured via `VITE_GOOGLE_OAUTH_CLIENT_ID`): Perfil → Google Calendar connects the vet's Google account (GIS popup consent) and creates a dedicated "Yoshi Vet Care" calendar. Every event she books/edits/cancels/deletes in a client's calendar is mirrored by Cloud Functions — client cancellations show as "CANCELADA · …" (graphite), deletions remove the Google event. Agenda rows show a sync chip (synced / error + retry / syncing) instead of the "Add to calendar" menu while connected. Perfil also offers "Sincronizar tudo" and "Desligar" (revokes the token; the Google calendar is kept for a possible reconnect).

## Data (Firestore)

| Path | What |
|---|---|
| `users/{uid}` | Profile. `userType` 0 client / 1 staff; `memberOf` (clinics where staff) and `clientOf` (clinics with an active link) are server-written; legacy `vetId` remains in docs but is unused by rules/app; `invitePending`/`invitedAt` track the access invite; optional `phone`, `phone2`, `address`, `postalCode`, `country`, `nif` (client and clinic staff can edit) |
| `clinics/{id}` | `name`, `isActive`, `brand`, `contact`; `members/{uid}` (role owner/vet) and `clients/{uid}` (link: pending/active/declined) — all server-written |
| `users/{uid}/pets/{petId}` | Pet; `medications/`, `symptoms/` below it |
| `users/{uid}/pets/{petId}/private/{noteId}` | Staff-only notes, `clinicId` per note |
| `users/{uid}/pets/{petId}/publicNotes/{noteId}` | Notes the clinic writes (`clinicId`); the owner reads all of them |
| `gcalTokens/{vetId}` | Google OAuth refresh token — server only, never readable |
| `gcalStatus/{vetId}` | Sync connection state; readable by that vet only |
| `users/{uid}/events/{eventId}` | Calendar entries. Clinic bookings carry `clinicId`, `vetId` (assigned), `bookedByVetId` (who booked), `clientName`, `petName`; personal client events have no `clinicId` and are visible to staff of every linked clinic; server-written `gcal` subfield tracks Google sync |
| `appointmentRequests/{id}` | Client → clinic requests (`clinicId`, `requestedVetId`, `vetId` = assignee or null = pool, `status`, `bookedDateTime`) |
| `chatRooms/{id}` + `messages/` | `clinicId`, `vetId` = assigned vet or null = pool (`unreadCounts.pool`), `requestedVetId` = the client's pick |

The clinic agenda is a collection-group query on `events` where `clinicId == clinic` (index in `firestore.indexes.json`); a composite `clinicId + vetId` index covers the per-vet filter.

Medication doses: scheduled slots go back up to 60 days (`pastDoseSlots`); taken doses are recorded in `doseHistory` and matched to slots by scheduled time (`matchDoseLogs`, with a day-level fallback for legacy logs). Creating a medication with a past start offers "Doses anteriores" (all / none / pick); the card's "Histórico de doses" menu edits them later — both go through one transaction.

## Functions (`functions/`, us-central1, Node 22, 256MiB)

- `gcalOnEventWrite` (Firestore trigger, max 2 instances): mirrors every write to a vet-booked event into Google Calendar; a `gcal.hash` guard skips its own write-back.
- `gcalConnect` (callable, max 1): exchanges the GIS authorization code, stores the refresh token, creates/finds the calendar, backfills upcoming events.
- `gcalSyncAll` (callable, max 1): re-syncs all upcoming vet bookings, or one event.
- `gcalDisconnect` (callable, max 1): revokes the token and marks the connection off.
- `createClientLogin` (callable, max 1, no secrets): creates the Auth user for a client added without email, using the profile doc id as uid. Caller must be an active member of a clinic the client is linked to.
- `addClinicClient` (callable, max 1): member adds a client to the clinic — new profile + active link, or a `pending` link when the email already has a client account.
- `respondClinicLink` (callable, max 1): the client accepts or declines a pending link.
- `createClinicVet` (callable, max 1): owner adds/reactivates a staff member (new users get an Auth user + `memberOf`).
- `updateClinicMember` (callable, max 1): owner changes role/active; refuses to leave zero active owners; deactivating releases that member's rooms and pending requests of the clinic back to the pool.

All cold-start free (`minInstances: 0`); Google calls go through plain `fetch` REST endpoints. Secrets: `GOOGLE_OAUTH_CLIENT_SECRET` via `firebase functions:secrets:set`; `GOOGLE_OAUTH_CLIENT_ID` as a functions env param (`.env.vetplus-digital`).

## Backlog

- Contact-consent checkbox for SMS/email reminders (waiting on the vet's wording/details).
- Vaccines and deworming section on the pet record (waiting on details).
- Email reminders via Resend — needs DNS records on yoshivetcare.com, an API key, and a scheduled function.
- SMS reminders — paid per message.
- Owner alert when the vet cancels an appointment.
- FCM push notifications when the app is closed.
- Move the app to app.yoshivetcare.com.

## Not in the app

- Push notifications: removed until server-side senders exist. The old Cloud Functions were clinic-based and live on the `archive/mobile-flutter` branch. In-app toasts for new chat messages still work, and users can grant browser-notification permission (Perfil → Notificações, or a one-time prompt) to get OS notifications while the app is open in a tab.
- Account deletion: not offered; the vet manages client accounts.
