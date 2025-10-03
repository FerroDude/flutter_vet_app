# Peton — For Development Plan (Authoritative Spec)

This document defines the end-to-end product and technical plan for the Peton mobile app purchased by veterinary clinics. It covers roles, features, data model, security, UX, delivery, and acceptance criteria, aligned with the current Flutter + Firebase implementation in `apps/mobile-flutter`.

## Summary: Code Architecture & Interactions

- App composition
  - `main.dart` initializes Firebase (`firebase_options.dart`), creates `CacheService` and `NotificationService` instances, and builds `MyApp`.
  - `app.dart:MyApp` injects globals via `MultiProvider`: `ThemeManager`, `CacheService`, `NotificationService`, `ClinicService`, `ChatService`.
  - `core/auth/auth_wrapper.dart` gates on `FirebaseAuth.authStateChanges()` and verified email, then creates user-scoped providers:
    - `UserProvider` (profile, clinic connection, role/permissions)
    - `EventProvider` (events + counts via `EventRepository` + `CacheService`)
    - `ChatProvider` (chat rooms/messages via `ChatService`)
  - Navigation is role-aware: App Owner → `pages/admin_dashboard.dart`; otherwise → `MyHomePage` (dashboard/pets/appointments/chat).

- State management
  - Provider + ChangeNotifier. Services/repositories are injected and used by providers; widgets subscribe to providers.

- Data flow (high level)
  - Auth: Email/password with email verification enforced in `AuthWrapper`.
  - First login: `UserProvider` loads/creates `UserProfile` in Firestore; “app owner” is granted by email allowlist logic in code.
  - Clinic connection: `ClinicService.connectUserToClinic` sets `users/{uid}.connectedClinicId` and appends to `users/{uid}/clinicHistory`.
  - Chat (1:1): `ChatService.findOrCreateOneOnOneChat` ensures a room for (clinicId, petOwnerId, vetId). Messages update `chatRooms/{id}.lastMessage` and increment `unreadCounts` for the other participant.
  - Events: `EventRepository` reads/writes `users/{uid}/events` with optional caching via `CacheService`. Notifications are currently a placeholder.

- Key files (quick links)
  - Entry: `apps/mobile-flutter/lib/main.dart:1`
  - Composition: `apps/mobile-flutter/lib/app.dart:1`
  - Auth gate: `apps/mobile-flutter/lib/core/auth/auth_wrapper.dart:1`
  - Providers: `apps/mobile-flutter/lib/providers/user_provider.dart:1`, `apps/mobile-flutter/lib/providers/event_provider.dart:1`, `apps/mobile-flutter/lib/providers/chat_provider.dart:1`
  - Services/Repo: `apps/mobile-flutter/lib/services/clinic_service.dart:1`, `apps/mobile-flutter/lib/services/chat_service.dart:1`, `apps/mobile-flutter/lib/repositories/event_repository.dart:1`, `apps/mobile-flutter/lib/services/cache_service.dart:1`
  - Models: `apps/mobile-flutter/lib/models/clinic_models.dart:1`, `apps/mobile-flutter/lib/models/chat_models.dart:1`, `apps/mobile-flutter/lib/models/event_model.dart:1`

## Firestore Schema Cheat Sheet (as implemented)

- `users/{userId}`
  - Fields: `email`, `displayName`, `userType` (enum index), `connectedClinicId?`, `clinicRole?`, `phone?`, `address?`, `hasSkippedClinicSelection` (bool), `isActive` (bool), `createdAt`, `updatedAt` (epoch ms or Timestamp).
  - `users/{userId}/events/{eventId}`: Calendar events (see `event_model.dart`).
  - `users/{userId}/clinicHistory/{historyId}`: `joinedAt`, `leftAt?`, `reason?`.
  - `users/{userId}/pets/{petId}` (planned): basic pet profile.

- `clinics/{clinicId}`
  - Fields: `name`, `address`, `phone`, `email`, `adminId`, `businessHours?`, `website?`, `description?`, `isActive`, `createdAt`, `updatedAt`.
  - `clinics/{clinicId}/members/{userId}`: `ClinicMember` with `role` (enum index), `permissions[]`, `addedAt`, `addedBy`, `isActive`, `lastActive?`.

- `chatRooms/{chatRoomId}`
  - Fields: `clinicId`, `petOwnerId`, `petOwnerName`, `vetId`, `vetName`, `petIds[]`, `lastMessage?`, `unreadCounts{uid:int}`, `isActive`, `topic?`, `createdAt`, `updatedAt`.
  - `chatRooms/{chatRoomId}/messages/{messageId}`: `ChatMessage` with `type` (text/image/appointment/medication), `status`, `timestamp`, optional `imageUrl`, `appointmentId`, `medicationId`, `metadata`.

- Enum mapping (used in code and rules)
  - `UserType`: petOwner=0, vet=1, clinicAdmin=2, appOwner=3.
  - `ClinicRole`: admin=0, vet=1.

Indexes to create (recommended)
- `chatRooms`: composite on `(vetId asc, isActive asc, updatedAt desc)` and `(clinicId asc, isActive asc, updatedAt desc)`.
- `users/{uid}/events`: single-field index on `dateTime`; filter/ordering combinations are simple.

## Security Rules Snapshot

- Source: `apps/mobile-flutter/firestore.rules:1`
- Key behaviors
  - Users can read/write their user doc, `events`, and `clinicHistory`.
  - Clinics: read active clinics; admins/app owner can create/update/delete; members visible to clinic members.
  - Chat: Only `petOwnerId` and `vetId` can read/write the room and its messages; `unreadCounts` maintained in the room document.

Note: Rules reference the same schema used by services/repository. Keep app and rules in lockstep when evolving the data model.

## Immediate Next Steps (Prioritized)

- Chat MVP (owner ↔ vet): wire inbox and room UI to `ChatProvider`/`ChatService`; start chat from owner and vet views; unread badges; mark read on open; vet/owner parity.
- Symptoms logging (calendar): add new event type and form to record daily pet symptoms; show on calendar and detail views; filter by pet and date.
- Re-enable event caching: ensure all date fields serialize to epoch ms before writing to cache; update readers accordingly.
- Local notifications: implement `NotificationService` with a supported plugin and schedule event reminders.
- Pets feature: add `users/{uid}/pets` (service + provider + UI), with optional Storage for photos.
- Chat push notifications: persist FCM tokens on `users/{uid}`; add Cloud Function to send push on new message.
- Image attachments: integrate Firebase Storage for chat images; update `ChatService` and room UI.
- Refactor `main.dart`: extract remaining UI into `lib/pages` and `lib/widgets` per existing refactor plan.
- Firestore indexes: create composites for chat room queries as listed above.

## Chat MVP (Owner ↔ Vet)

- Scope
  - Owner and Vet can list their chat rooms; open a room; send/receive text messages in real time; unread badges; mark-as-read on open.
  - Start chat: Owner selects a vet from their connected clinic; Vet can start/respond from their inbox.

- UI & Routing
  - Owner: add “Start Chat” entry point from clinic connection or chat tab; list rooms with last message + unread count.
  - Vet: chat inbox view listing rooms filtered by `vetId`; open `chat_room_page.dart` for conversation.
  - Use existing files: `pages/chat_page.dart`, `pages/chat_room_page.dart`, `providers/chat_provider.dart`.

- Backend & Data
  - Use `ChatService.findOrCreateOneOnOneChat(clinicId, petOwnerId, vetId)` to create room.
  - Messages stored at `chatRooms/{id}/messages`; `unreadCounts` map maintained per room; `markMessagesAsRead` on enter.
  - Create Firestore composite indexes for `(vetId, isActive, updatedAt)` and `(clinicId, isActive, updatedAt)`.

- Security
  - Already enforced in `firestore.rules`: only `petOwnerId` or `vetId` can access room/messages.

- Acceptance Criteria
  - Owner can start chat with connected clinic’s vet; vet sees new room in inbox.
  - Messages stream in real time; unread counts update; entering a room clears count for that user.
  - No access to rooms by unrelated users or other clinics.

- Tasks
  - Wire chat list to `ChatProvider` streams for both roles; add “start chat” flow.
  - Implement message input/send; show typing/empty states; optimistic UI where safe.
  - Badge counts in nav; call `markMessagesAsRead` on room open; paginate messages (e.g., 50 at a time).
  - Add minimal error and offline states; instrument basic analytics (message_send, chat_open).

### Technical Details

- Firestore data contract
  - `chatRooms/{id}`: `{ clinicId: string, petOwnerId: string, petOwnerName: string, vetId: string, vetName: string, petIds: string[], lastMessage?: ChatMessage, unreadCounts: { [uid]: number }, isActive: bool, topic?: string, createdAt: int(ms), updatedAt: int(ms) }`
  - `chatRooms/{id}/messages/{mid}`: `{ chatId: string, senderId: string, senderName: string, senderRole: 'pet_owner'|'vet'|'admin', content: string, type: MessageType(index), status: MessageStatus(index), timestamp: int(ms), imageUrl?: string, appointmentId?: string, medicationId?: string, metadata?: map }`
  - Timestamps stored as epoch ms in documents; security rules already restrict access to participants.

- Indexes (Firestore)
  - Composite: `(vetId asc, isActive asc, updatedAt desc)` on `chatRooms` for vet inbox.
  - Composite: `(clinicId asc, isActive asc, updatedAt desc)` on `chatRooms` for clinic admin views.
  - Single-field: `timestamp` on `chatRooms/{id}/messages` for ordering/pagination.

- Service/provider APIs (to use or add)
  - `ChatService`
    - Already: `findOrCreateOneOnOneChat`, `getVetChatRooms()`, `vetChatRoomsStream()`, `getMessages()`, `sendMessage()`, `markMessagesAsRead()`.
    - Add: `Future<List<ChatRoom>> getOwnerChatRooms(String ownerId)` and `Stream<List<ChatRoom>> ownerChatRoomsStream(String ownerId)` filtering `petOwnerId`.
    - Improve: In `sendMessage`, update unread via `FieldValue.increment(1)` on `unreadCounts.{otherUid}` to avoid race conditions.
  - `ChatProvider`
    - Ensure: `selectChatRoom(String chatRoomId)`, `leaveChatRoom()`, `sendTextMessage(String content)`.
    - Add: `Future<void> loadMoreMessages()` using `startAfterDocument` for pagination; maintain last snapshot.

- Pagination strategy
  - Messages fetched in pages of 50 (descending by `timestamp`), `ListView` with `reverse: true` and infinite scroll on reaching top to load older messages.

- Error/edge handling
  - Offline send: rely on Firestore offline persistence; show queued state locally, update status upon server ack (optional future enhancement).
  - Deactivated rooms: respect `isActive=false` by disabling input and showing a banner.
  - Consistency: include `id` when embedding `lastMessage` in `chatRooms` (e.g., set `lastMessage.id = messageRef.id`) or store `lastMessageId` alongside the embedded map.

- Push notifications (Phase B)
  - Store user tokens: `users/{uid}.fcmTokens.{deviceId} = { token, platform, updatedAt }`.
  - Cloud Function (Node): `onCreate` of `chatRooms/{id}/messages/{mid}`; determine recipient (other participant) and send FCM data message with `chatRoomId`.
  - App handler: on background/open, navigate to `ChatRoomPage` using `navigatorKey`.
  
- Image attachments (Phase B)
  - Storage path: `chat_uploads/{chatRoomId}/{uuid}.jpg` (or `.png`), `contentType` set appropriately.
  - Storage rules: allow read/write if requester is `petOwnerId` or `vetId` of `chatRooms/{chatRoomId}` (validate via Firestore get in rules).
  - Message flow: upload image, obtain download URL, then call `sendMessage(type: image, imageUrl: ...)`.

## Symptoms Logging (Calendar)

- Goal
  - Allow pet owners to record daily symptoms per pet and review history on the calendar and detail views.

- Data Model
  - Add `EventType.symptom` and `SymptomEvent` in `lib/models/event_model.dart` (fields: `symptoms[]` or structured entries, `severity?` 1–5, `notes?`, required `petId`, `dateTime`, `userId`, standard audit fields).
  - Store under `users/{uid}/events/{eventId}` to reuse repository and calendar.
  - Backward compatibility: append enum value at the end to preserve existing type indices.

- Repository & Provider
  - Update `EventRepository` to parse `symptom` events; include in filtering and counts where relevant (or add separate “health logs” count).
  - Extend `EventProvider` APIs to create/update/delete `SymptomEvent`.

- UI
  - Add “Add Symptoms” action in calendar/day view and pet detail, backed by a simple form (symptom list, severity slider, notes).
  - Display symptom markers on the calendar; show in day list with icon/color distinct from notes.
  - Filtering by pet and date range; optional keyword filter.

- Security
  - Uses existing `users/{uid}/events` rules; no changes required.

- Acceptance Criteria
  - Owner can add/edit/delete a symptom entry for a pet and date.
  - Entries appear on the selected day and in the pet’s history; persisted across sessions; respects offline cache when added.
  - Does not break existing appointment/medication flows.

- Tasks
  - Models: add enum + `SymptomEvent` with (de)serialization; update fromJson factory.
  - Forms: add UI in `widgets/event_forms.dart` or `widgets/simple_event_forms.dart` for symptoms.
  - Calendar: show symptom chips/indicators in `widgets/calendar_view.dart`; add filter.
  - Counts: update dashboard counts if symptoms are included; otherwise add separate health log metric.

### Technical Details

- Data model additions
  - Extend `EventType` by appending `symptom` at the end to preserve existing indices: `appointment=0, medication=1, note=2, symptom=3`.
  - New `class SymptomEvent extends CalendarEvent` with fields:
    - `List<String> symptoms` (e.g., ['vomiting','lethargy'])
    - `int? severity` (1–5)
    - `String? notes`
    - Inherits: `id`, `title`, `description` (optional short summary), `dateTime` (anchor day), `petId`, `userId`, `createdAt`, `updatedAt`.
  - Serialization: all dates as epoch ms; `toJson()` mirrors existing event classes.

- Repository/provider changes
  - Update `CalendarEvent.fromJson` switch to handle `EventType.symptom`.
  - Include `symptom` in filters where appropriate; or provide a dedicated filter flag in `EventRepository.getEvents`.
  - `EventProvider`: expose `createSymptomEvent`, `updateSymptomEvent`, `deleteSymptomEvent` wrappers.

- UI and UX
  - Form: add a simple multi-select/tag input for symptoms, a severity slider (1–5), and notes field.
  - Calendar: add a distinct icon/color for symptoms in `widgets/calendar_view.dart`; tapping opens detail/edit.
  - Day view: group by type; show symptoms with chips for quick scanning.

- Timezone/day boundaries
  - Compute start/end of day using `package:timezone` to avoid DST issues; query `dateTime` between `[startMs, endMs)`.

- Validation
  - Require at least one symptom or non-empty notes; require `petId`.

- Telemetry
  - Analytics events: `symptom_create`, `symptom_update`, `symptom_delete` with `petId`, `severity`, and symptom count (no PII).

## Implementation Tasks by File

- Chat
  - `lib/services/chat_service.dart`
    - Add: `Future<List<ChatRoom>> getOwnerChatRooms(String ownerId)` and `Stream<List<ChatRoom>> ownerChatRoomsStream(String ownerId)`.
    - Change: In `sendMessage`, update `unreadCounts.{otherUid}` via `FieldValue.increment(1)`; set `updatedAt` with `FieldValue.serverTimestamp()`.
    - Add: message pagination helpers returning `Query` with `startAfterDocument` support.
  - `lib/providers/chat_provider.dart`
    - Add: `loadMoreMessages()` maintaining last message snapshot; expose `hasMore` state.
    - Ensure: `selectChatRoom` sets up stream and resets unread via `markMessagesAsRead`.
  - `lib/pages/chat_page.dart`
    - Owner/Vet inbox: subscribe to proper stream (`ownerChatRoomsStream` vs `vetChatRoomsStream`); add “Start Chat” flow for owner.
  - `lib/pages/chat_room_page.dart`
    - Hook up message list with pagination (`reverse: true`); call `sendTextMessage` and clear input; call `markMessagesAsRead` on open.

- Symptoms
  - `lib/models/event_model.dart`
    - Append `EventType.symptom`; implement `class SymptomEvent extends CalendarEvent` with (de)serialization.
    - Update `CalendarEvent.fromJson` switch and `copyWith` signatures where needed.
  - `lib/providers/event_provider.dart`
    - Add methods to create/update/delete `SymptomEvent`; broadcast changes to listeners.
  - `lib/repositories/event_repository.dart`
    - Ensure `getEvents` returns symptom events; update counts logic if symptoms are included in summaries.
  - `lib/widgets/event_forms.dart` or `lib/widgets/simple_event_forms.dart`
    - Add a new symptom form widget with tags/multi-select, severity slider, and notes field.
  - `lib/widgets/calendar_view.dart`
    - Render symptom markers and filter options; ensure day range queries are timezone-safe.

- Indexes & Rules
  - Firestore: add composites for `chatRooms` and single-field index on `messages.timestamp` if prompted.
  - Rules: no change required for symptoms (under `users/{uid}/events`).

- Testing
  - Unit: `ChatService.sendMessage` unread increment; `EventRepository` parsing of `SymptomEvent`.
  - Widget: chat inbox renders rooms/unreads; message pagination; symptom form validation and save.
  - Integration: owner–vet message flow; symptom create → appears on calendar day list.

## Cache Serialization Details

- Events cache blob (SharedPreferences key: `cached_events`)
  - Schema:
    - `schemaVersion`: 1
    - `userId`: string
    - `timestamp`: int(ms) cache write time
    - `events`: CalendarEvent[] serialized with epoch ms for all dates
  - Example:
```
{
  "schemaVersion": 1,
  "userId": "abc123",
  "timestamp": 1735948800000,
  "events": [
    {
      "id": "evt1",
      "title": "Checkup",
      "description": "Annual exam",
      "dateTime": 1736035200000,
      "type": 0,
      "petId": "pet1",
      "userId": "abc123",
      "createdAt": 1735948800000,
      "updatedAt": 1735948800000,
      "isRecurring": false
    }
  ]
}
```
- TTL: 2h (see `EventRepository._cacheValidity`).
- On cache read, validate `userId` and TTL before hydrating `CalendarEvent` via `fromJson`.

## 1. Product Scope

- Purpose: Communication tool between pet owners and clinics; no in‑app scheduling.
- Platforms: Android, iOS (Flutter). Optional web later.
- Tenancy: Multi‑tenant by clinic; strong data isolation across clinics.
- Connectivity: Works online-first with basic offline tolerance for events; chat requires connectivity.

## 2. Roles & Responsibilities

- App Owner (you):
  - Create/manage Clinics and Clinic Admins.
  - Global oversight; support and compliance tasks.
- Clinic Admin:
  - Owns a clinic space; manages clinic settings, business hours.
  - Creates and manages Vet accounts (invites, activate/deactivate, permissions).
  - Oversees patient conversations for the clinic.
- Clinic Vet:
  - Communicates with linked pet owners.
  - Access to chats, pet info shared by owners, and clinic calendar context (read-only for now).
- Pet Owner:
  - Onboards to app, creates pet profiles, manages appointments/medications (personal calendar).
  - Connects to one clinic at a time to enable chat with its vets.

Notes:
- Pet Owner clinic connection is exclusive (one at a time). Switching clinics is supported via disconnect → connect to a different clinic.
- No appointment scheduling via app; events are personal reminders, optionally shared in chat context.

## 3. Core Feature Map (Epics → Stories)

3.1 Authentication & Identity
- Email/password sign up, sign in, sign out (email verification required).
- App Owner recognition by allowlist (current implementation uses static email list).
- Password reset via email.
- Acceptance: Verified email gating; role routing works per `AuthWrapper`.

3.2 App Owner Console
- Create Clinic: name, address, phone, email, website, business hours, description, isActive.
- Assign Clinic Admin:
  - Option A (current behavior): Create placeholder admin profile by email; link on first login.
  - Option B (future): Invitation flow with secure token and Cloud Function to link upon signup.
- Deactivate/reactivate clinics and admins.
- Acceptance: Clinic visible to signed-in users only if `isActive == true`.

3.3 Clinic Admin Console
- Manage clinic settings (as above).
- Manage Vets:
  - Create Vet account (email invitation or direct creation if policy allows).
  - Activate/deactivate; set permissions (scopes list below).
- Monitor Conversations: List of chat rooms in clinic.
- Acceptance: Only admins of that clinic can modify members.

3.4 Vet Workspace
- Chat Inbox: List of owner conversations for the vet, sorted by recent activity.
- Chat Room: Send/receive messages, see pet owner’s shared pet info snippets, send text.
- Acceptance: Access restricted to vet’s own chat rooms.

3.5 Pet Owner App
- Clinic Connection: Search active clinics; connect or disconnect.
- Chat: Start a conversation with clinic; see list; send/receive messages.
- Pets: CRUD for pets (name, species, breed, DOB, notes, photo optional).
- Calendar: Events for appointments/medications/notes with recurrence, counts.
- Sharing: Share event summaries in chat; pet info is implicitly visible to clinic while connected.
- Acceptance: Chat disabled until connected to a clinic.

3.6 Notifications (Phased)
- Phase A: Local notifications (device reminders for events) — currently a placeholder.
- Phase B: Push notifications (FCM) for new chat messages and critical reminders.
- Acceptance: Toggle in settings; respects OS permissions.

3.7 Analytics & Logging
- Crash reporting (Crashlytics), usage metrics (Firebase Analytics), privacy compliant.
- Acceptance: No PII in analytics events; opt‑out respected where required.

## 4. Permissions Matrix (Summary)

- Pet Owner:
  - Read/write: own `users/{uid}`, `events`, `clinicHistory`, pets collection (to be added).
  - Chat rooms where `petOwnerId == uid`.
- Vet:
  - Read: clinic chat rooms where `vetId == uid`; messages thereof.
  - No write access to clinic profile unless granted permissions (future scope).
- Clinic Admin:
  - Read/Write: clinic doc and `members` subcollection for their clinic.
  - Read: all chat rooms/messages in their clinic (monitoring).
- App Owner:
  - Read/Write: all clinics and member configurations.

Permissions detail is enforced by Firestore rules in `apps/mobile-flutter/firestore.rules`.

## 5. Data Model (Firestore)

Collections & Subcollections (current + planned)
- `users/{userId}`
  - Fields: email, displayName, userType (enum), connectedClinicId?, clinicRole?, phone?, address?, hasSkippedClinicSelection, isActive, createdAt, updatedAt.
  - `events/{eventId}`: calendar events (appointments/medications/notes); fields as per `lib/models/event_model.dart` with epoch timestamps.
  - `clinicHistory/{historyId}`: joinedAt, leftAt, reason.
  - `pets/{petId}` (planned): name, species, breed, sex, DOB, color, identifiers, notes, photoUrl.

- `clinics/{clinicId}`
  - Fields: name, address, phone, email, adminId, isActive, website?, description?, businessHours?, createdAt, updatedAt.
  - `members/{userId}`: role (enum admin=0, vet=1), permissions[], isActive, addedAt, addedBy, lastActive.

- `chatRooms/{chatRoomId}`
  - Fields: clinicId, petOwnerId, petOwnerName, vetId, vetName, petIds[], lastMessage (embedded), unreadCounts (map), topic?, isActive, createdAt, updatedAt.
  - `messages/{messageId}`: chatId, senderId, senderName, senderRole, content, type (enum), status, timestamp, imageUrl?, appointmentId?, medicationId?, metadata?.

Indexes (recommended)
- chatRooms: vetId + isActive + orderBy(updatedAt desc)
- chatRooms: petOwnerId + isActive + orderBy(updatedAt desc)
- clinics: isActive + orderBy(name) (for name prefix search paired with startAt/endAt)
- users.events: orderBy(dateTime) (single-field index; Firestore provides by default)

## 6. Security Rules (Alignment)

- Users own their documents and subcollections.
- Clinic docs readable by signed-in users only if `isActive == true`; writable by clinic admin or app owner.
- Chat rooms/messages accessible only to participants (petOwnerId or vetId) and clinic admins for monitoring if policy permits (future option — currently participants only; admin reads can be added once UI supports it).
- Rules file: `apps/mobile-flutter/firestore.rules`.

## 7. UX & Navigation

Top-Level Navigation (tabs for non-owner roles)
- Dashboard
- Pets
- Appointments
- Messages

Conditional Routes
- App Owner → Admin Dashboard
- Clinic Admin → Clinic Admin screens via tab or menu
- Vet → Messages, read-only clinic info
- Pet Owner (no clinic) → Prompt to connect clinic in Messages

Design System
- Centralized theme in `lib/theme`.
- Consider per‑clinic branding (logo, primary color) in future: set theme overrides based on connected clinic.

Accessibility
- Minimum 44dp touch targets, color contrast AA+, dynamic type support.

## 8. Feature Specs & Acceptance Criteria

8.1 Clinic Creation (App Owner)
- Inputs: name, address, phone, email, website?, description?, hours.
- Output: Clinic doc with `isActive=true` and admin placeholder or real admin user.
- Accept: Clinic appears in search for signed-in users; admin can sign in and manage.

8.2 Vet Management (Clinic Admin)
- Create Vet: enter email, set permissions, add to members.
- Activate/Deactivate: toggles isActive; removes chat access when inactive.
- Accept: Vet sees clinic chat rooms on next login; deactivated vets lose access.

8.3 Clinic Search & Connect (Pet Owner)
- Search: prefix by name; filter where `isActive==true`.
- Connect: sets `users/{uid}.connectedClinicId`, creates history row.
- Accept: Messages tab becomes enabled and shows start-conversation action.

8.4 Chat (Pet Owner ↔ Vet)
- Create or find room: unique on (clinicId, petOwnerId, vetId).
- Send text messages; update `unreadCounts` for the other participant.
- Mark as read on room open.
- Accept: Real-time message flow; unread badges reflect counts.

8.5 Pets (Owner)
- CRUD pets; optionally attach photo via Firebase Storage (phase B).
- Share implicitly with clinic while connected (read-only for vets/admins).
- Accept: Pet list and details work offline (local cache), sync when online.

8.6 Calendar & Events (Owner)
- Types: appointment, medication, note; recurrence for medication.
- Counts: today, tomorrow, thisWeek, total.
- Local reminders: optional device notifications for upcoming items (phase A placeholder, phase B real).
- Accept: Create/edit/delete; recurrence and completion create next instance correctly.

8.7 Notifications
- Local (phase A): Implement with `awesome_notifications` (or similar) for event reminders.
- Push (phase B): FCM via Cloud Functions on new chat message to notify the other participant.
- Accept: Opt-in, cancel, reschedule; app notifies reliably.

8.8 Privacy & Compliance
- Data isolation per clinic; owners control clinic connection.
- Delete Account (owner): removes `users/{uid}` and subcollections (best-effort purge of chats not owned).
- Accept: GDPR-style export/delete optional future.

## 9. Technical Plan & Milestones

M0: Baseline/Refactor (in code)
- Follow `REFACTOR.md` Phases 1–8 to modularize UI without behavior changes.

M1: Pets Collection (backend + UI)
- Add `users/{uid}/pets` schema, service, provider, pages.
- Optional photo uploads with Storage; enforce size/type limits.

M2: Notifications (local)
- Implement `NotificationService` with a supported plugin.
- Schedule, cancel, reschedule; background handling.

M3: Push Messaging (chat)
- Add FCM token storage on user doc; Cloud Function `onCreate(messages)` to route notifications.
- Background handling in Flutter to open chat room.

M4: Vet/Admin Enhancements
- Admin dashboard KPIs, vet permissions (e.g., chat-only vs. can view shared pet info), activity audit.

M5: Analytics/Crashlytics
- Configure Firebase Analytics + Crashlytics; add key events (clinic_connect, message_send, event_create).

M6: Branding (optional)
- Per-clinic theme overlays (logo, colors) loaded from clinic doc.

## 10. Services/Providers Work Breakdown

- ClinicService: complete CRUD; invite flows; member activation.
- ChatService: finalize streams; add push hooks (future function integration).
- EventRepository: re‑enable caching with epoch timestamps only; add version key in cache blob.
- CacheService: implement `cacheEvents(userId, events)` safely; add schema version, TTL, and migration path.
- UserProvider: streamline app owner detection; replace hardcoded allowlist with Firestore list (future).
- New PetService + PetProvider: CRUD under `users/{uid}/pets` and shared views for vets.

## 11. Testing Strategy

- Unit: services (ClinicService, ChatService, EventRepository), providers change notifications.
- Widget: chat list/room, events list/forms, pets pages.
- Integration: auth → role routing; clinic connect → chat enabled; event lifecycle.
- Manual regression: Navigation, dark mode, localization basics.

## 12. CI/CD & Environments

- Flavors: development, staging, production.
- Secrets: Firebase configs via `firebase_options.dart` per environment.
- CI: build + analyze; block on errors; optional unit tests.
- Release: Play Store/App Store with versioning `major.minor.patch+build`.

## 13. Telemetry & KPIs

- Activation: daily/weekly active users by role.
- Engagement: messages per user, time-to-response.
- Retention: clinic churn, owner return rate.
- Reliability: crash-free sessions, message delivery success.

## 14. Risk & Mitigation

- Chat latency/scale: Use indexed queries; paginate messages; consider RTDB for presence if needed later.
- Push reliability: Fallback to local reminders for events; retries via Functions.
- Data privacy: Strict rules; admin visibility only within clinic scope; audit log optional future.

## 15. Open Questions / Future

- Group chats (owner + multiple vets)?
- Owner-to-clinic broadcast (triage)?
- Attachments (images/docs) in chat with Storage.
- Export data, data residency requirements.

---

Appendices

A) Firestore Indexes JSON (example)

- Create via Firebase Console when prompted; export with `firebase firestore:indexes`.
- Example `firestore.indexes.json` entries for chat:

```
{
  "indexes": [
    {
      "collectionGroup": "chatRooms",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "vetId", "order": "ASCENDING" },
        { "fieldPath": "isActive", "order": "ASCENDING" },
        { "fieldPath": "updatedAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "chatRooms",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "clinicId", "order": "ASCENDING" },
        { "fieldPath": "isActive", "order": "ASCENDING" },
        { "fieldPath": "updatedAt", "order": "DESCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

B) Message Types (enum)
- text, image (future), appointment, medication.

C) Permissions (fine-grained, future)
- vet_can_view_pets, vet_can_view_history, admin_can_view_all_chats, etc.

D) Acceptance Checklists (per epic)
- Track in issues; mirror high-level acceptance above.

This plan is the single source of truth for development scope and decisions. Keep it synced with code and rules.
