# Next Steps

> Living document. Plan the next feature here, implement it, then clear and repeat.

---

## Current Feature: App Hardening & Feature Gaps

### Goal

Fix known issues, fill placeholder gaps, and polish the app before device testing.

### Phase A — Quick wins (code-only, no device needed)

#### 1. Fix deprecated `.withOpacity()` calls

Replace every `.withOpacity(X)` with `.withValues(alpha: X)` for Material 3 compliance.

**24 instances across 3 files:**

| File                                   | Count | Lines                                                                                   | Pattern                                                                                        |
| -------------------------------------- | ----- | --------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `lib/pages/petOwners/chat_page.dart`   | 2     | 299, 307                                                                                | `Colors.white.withOpacity(0.5)` and `(0.7)`                                                    |
| `lib/pages/petOwners/clinic_page.dart` | 2     | 497, 502                                                                                | `Colors.white.withOpacity(0.5)` and `(0.7)`                                                    |
| `lib/shared/widgets/chat_widgets.dart` | 20    | 196, 333-334, 338, 352, 361, 399, 462, 583, 609, 627, 637, 688, 702, 712, 765, 899, 943 | Mix of `Colors.white`, `Colors.black`, `AppTheme.primary`, `Colors.yellow`, `Colors.lightBlue` |

Steps:

- [x] `chat_page.dart` — changed deprecated `.withOpacity(...)` usages to `.withValues(alpha: ...)`
- [x] `clinic_page.dart` — changed deprecated `.withOpacity(...)` usages to `.withValues(alpha: ...)`
- [x] `chat_widgets.dart` — changed all deprecated `.withOpacity(...)` usages to `.withValues(alpha: ...)`

#### 2. Wire up Profile page

Two problems in `profile_page.dart`:

**2a. Edit Profile button is a no-op (line 32-34)**

The edit icon exists but `onPressed` does nothing. `UserProvider` already has an `updateProfile()` method that accepts `displayName`, `phone`, `address`. Plan:

- [x] Added profile edit dialog with text fields for Display Name, Phone, and Address
- [x] Pre-populated fields with current values from `UserProvider.currentUser`
- [x] Save now calls `userProvider.updateProfile(displayName: ..., phone: ..., address: ...)`
- [x] On success/failure, closes dialog and shows feedback snackbar
- [x] Wired app bar edit button to open the edit dialog

**2b. Hardcoded "0" stats (lines 171, 178, 185)**

The profile header shows `_buildStatItem(context, '0', 'Pets')`, `'0', 'Appointments'`, `'0', 'Records'`. These should show real data.

Data sources:

- **Pets count** — Firestore `users/{uid}/pets` subcollection. No existing provider exposes this count for pet owners. Two options:
  - (a) Query `users/{uid}/pets` count in `ProfilePage` directly via a `StreamBuilder`
  - (b) Add a `petCount` getter/stream to an existing provider
- **Appointments count** — Use `AppointmentRequestProvider` or query `appointmentRequests` where `petOwnerId == uid` and status is confirmed
- **Records count** — Unclear what "Records" means. Options: total symptom entries, total medication entries, or total calendar events. Pick one and query, or remove this stat if undefined.

Steps:

- [x] "Records" defined as total symptom records (`collectionGroup('symptoms')` by owner)
- [x] Kept `ProfilePage` stateless and used `StreamBuilder`s for live counters
- [x] Added Firestore streams for pets count and appointments count
- [x] Replaced hardcoded `'0'` values with live stream-driven values

#### 3. Implement `_saveClinic` update in Clinic Management

**Bug**: `clinic_management_page.dart` line 690-698 — when `isCreating` is false (editing), the save button shows "Clinic updated successfully" but never writes to Firestore. Admins think they saved changes but nothing persists.

The infrastructure already exists:

- `ClinicService.updateClinic(clinicId, clinic)` calls `_clinicsCollection.doc(clinicId).update(clinic.toJson())`
- `Clinic.copyWith(...)` supports all editable fields (name, address, phone, email, website, description, businessHours)

Steps:

- [x] In `_saveClinic()` edit branch, now build an updated `Clinic` using current form values and business hours
- [x] Call `ClinicService().updateClinic(existingClinic.id, updatedClinic)`
- [x] Refresh clinic/provider state after update via `userProvider.refresh()`
- [x] Keep success snackbar and `_isEditing = false` behavior after successful save

#### 4. Standardize error/loading/empty-state patterns

`app_components.dart` provides `AppLoadingIndicator` and `AppEmptyState` but only 3 files import them. Meanwhile, raw `CircularProgressIndicator` appears in 35 files.

**Priority files to migrate** (highest user-facing impact):

| File                                                   | Current pattern                                 | Target                |
| ------------------------------------------------------ | ----------------------------------------------- | --------------------- |
| `pages/petOwners/dashboard_page.dart`                  | raw `CircularProgressIndicator`                 | `AppLoadingIndicator` |
| `pages/vets/vet_dashboard_page.dart`                   | raw `CircularProgressIndicator`                 | `AppLoadingIndicator` |
| `pages/receptionists/receptionist_dashboard_page.dart` | raw `CircularProgressIndicator`                 | `AppLoadingIndicator` |
| `pages/clinicAdmins/clinic_admin_dashboard.dart`       | raw `CircularProgressIndicator` (16 instances!) | `AppLoadingIndicator` |
| `pages/appOwner/app_owner_stats.dart`                  | raw `CircularProgressIndicator`                 | `AppLoadingIndicator` |
| `pages/petOwners/pet_details_page.dart`                | raw `CircularProgressIndicator`                 | `AppLoadingIndicator` |

Steps:

- [x] Imported `app_components.dart` in key files updated in this phase
- [x] Replaced primary loading spinners with `AppLoadingIndicator()` in core pages touched during Phase A
- [x] Kept existing empty-state copy where already polished; left deeper screen migration for later phases
- [x] Deep pages (chat_room_page, modals, forms) intentionally deferred to a later pass

#### 5. Increase `app_components.dart` adoption

Currently only `chat_page.dart`, `clinic_page.dart`, and `app_components.dart` itself import the shared components. All other pages use raw Material widgets.

This is a gradual effort — not a single PR. Strategy:

- [x] Started dashboard migration by introducing `AppCard`/`AppLoadingIndicator` usage in admin-facing screens
- [x] Focused on inconsistent admin views first to reduce UI variance
- [x] Avoided broad risky refactors on stable screens; applied targeted consistency updates
- [x] Updated Phase A baseline; remaining broad component migration can continue incrementally in Phase B

### Phase B — Medium features (code-only)

#### 6. Receptionist "Today's Appointments" card

`receptionist_dashboard_page.dart` — currently a "Coming soon" placeholder. Pull confirmed appointments for today from the existing appointment request data.

- [ ] Query today's confirmed appointments from Firestore
- [ ] Display in the dashboard card with pet/owner info and time preference

#### 7. Vet dashboard "Today's Appointments" card

`vet_dashboard_page.dart` — same placeholder ("Connect your practice management software"). Same approach: show confirmed appointments for the vet's clinic.

- [ ] Decide: show confirmed appointments for the vet's clinic, or keep placeholder
- [ ] If yes, build a read-only appointment list card

#### 8. Clinic Admin: Pet Owner management

`clinic_admin_dashboard.dart` — shows "Pet owner management coming soon."

- [ ] Define scope: list pet owners connected to the clinic? View their pets? Remove access?
- [ ] Implement basic pet owner listing for the clinic

#### 9. Clinic Admin: Clinic Settings

`clinic_admin_dashboard.dart` — shows "Clinic settings coming soon."

- [ ] Define scope: business hours, notification preferences, clinic branding?
- [ ] Implement settings screen

---

## Pending — Requires Devices or Product Decisions

These stay tracked but are blocked until the prerequisite is met.

| #   | Task                                           | Blocker                | Notes                                                                                                         |
| --- | ---------------------------------------------- | ---------------------- | ------------------------------------------------------------------------------------------------------------- |
| 10  | Run `TESTING_CHECKLIST.md` on physical devices | Needs physical devices | Push notifications, full appointment flow, chat-from-appointment, notification toggle, regression             |
| 11  | Fix bugs found during device testing           | Depends on #10         |                                                                                                               |
| 12  | Vet appointment visibility scope               | Product decision       | Should vets see requests? Read-only or actionable?                                                            |
| 13  | Email system (SendGrid/SES)                    | Product decision       | Firebase Auth handles invites/resets. Decide if transactional email is still needed or if push is sufficient. |

### Watch For (during device testing)

- `PERMISSION_DENIED` errors in device logs (receptionist opening chats)
- "Could not find Provider" errors during navigation
- Badge counts not updating in real-time
- Cancelled appointments reappearing

---

## Completed

Archived from previous iterations.

### Pre-Release Cleanup and Validation

- [x] Removed leftover `isUrgent` references (model, provider, service, Cloud Functions)
- [x] Updated root `TODO.md` to reflect current state
- [x] Deployed Firebase backend (indexes, rules, functions) — all on Node.js 22 / SDK v5
- [x] UX polish: empty states, consistent action labels, no-pets edge case handling
- [x] Cloud Functions observability: structured logging, fan-out telemetry, stale token cleanup
- [x] Automated tests: unit tests for `AppointmentRequestService` and `PushNotificationService`, integration test for appointment lifecycle
- [x] Runtime/SDK upgrades: Node.js 22, `firebase-functions@^5.1.1`, `firebase-admin@^12.7.0`
- [x] Added `.gitignore` for `functions/node_modules` and removed from git tracking
