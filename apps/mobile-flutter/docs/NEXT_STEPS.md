# Next Steps

> Living document. Plan the next feature here, implement it, then clear and repeat.

---

## Current Feature: Pre-Release Cleanup and Validation

### Goal

Stabilize the appointment request system, push notifications, and unified Clinic tab before release.

### Tasks

#### 1. Remove leftover `isUrgent` references

The urgent toggle was removed from the UI but remnants remain in backend and model code.

Files to clean:

- [x] `functions/index.js` — removed `isUrgent` handling and urgent notification title branch
- [x] `lib/models/appointment_request_model.dart` — removed `isUrgent` from model and serialization
- [x] `lib/providers/appointment_request_provider.dart` — removed `urgentCount` and `isUrgent` plumbing
- [x] `lib/services/appointment_request_service.dart` — removed `isUrgent` field from request creation

#### 2. Update `TODO.md`

Root `TODO.md` is outdated. It still lists push notifications as a future enhancement and doesn't mention appointments, receptionist role, or the Clinic tab.

- [x] Mark push notifications as completed
- [x] Add appointment request system as completed
- [x] Add receptionist role as completed
- [x] Add unified Clinic tab as completed
- [x] Update "Current Focus" section
- [x] Review "In Progress" items (email system — still needed or replaced by push?)

#### 3. Deploy Firebase backend

Status: ✅ Completed

Run in this order:

```bash
firebase deploy --only firestore:indexes
firebase deploy --only firestore:rules
firebase deploy --only functions
```

Latest deployment notes:

- ✅ `firestore:indexes` deployed successfully
- ✅ `firestore:rules` deployed successfully
- ✅ `functions` deployed successfully (`onClinicMemberCreate`, `onAppointmentRequestCreated`, `onAppointmentRequestUpdated`)
- ⚠️ Runtime/SDK follow-up: Functions are on Node.js 20 (deprecation notice) and `firebase-functions` package is outdated (`4.9.0`)

#### 4. Run `TESTING_CHECKLIST.md` on physical devices

Status: 🔄 In progress

Priority order:

1. Push notifications (create appointment -> receptionist notified -> confirm -> pet owner notified)
2. Full appointment flow (create, view, confirm, deny, cancel/delete)
3. Chat-from-appointment (previously had PERMISSION_DENIED)
4. Clinic tab filtering and FAB behavior
5. Notification settings toggle (on/off per role)
6. Regression: existing chat, vet, clinic admin flows

#### 5. Fix any bugs found during testing

Status: ⏳ Pending (depends on test execution)

#### 6. UX polish

Status: ✅ Completed (digital implementation)

- [x] Empty state messages for each Clinic tab filter
- [x] Consistent action labels between pet owner and receptionist views
- [x] Edge case: pet owner with no pets tries to request appointment

### Watch For

- `PERMISSION_DENIED` errors in device logs (receptionist opening chats)
- "Could not find Provider" errors during navigation
- Badge counts not updating in real-time
- Cancelled appointments reappearing

---

## Backlog

Features to plan after the current one is done.

### Vet appointment visibility

Vets currently don't see appointment requests. Decide whether they should have read-only access, actionable access, or stay chat-only.

### Clinic Admin appointment visibility

Admin dashboard is management-focused but doesn't surface appointment requests. Consider whether admins need a feed view.

### Cloud Functions observability

Status: ✅ Completed

- [x] Added structured logs for push attempt/success/skip/failure events
- [x] Added structured logs for fan-out results (target/sent/failed counts)
- [x] Added trigger-level logs for appointment create/update flows
- [x] Added automatic invalid/expired token cleanup on send failure
- [x] Follow-up implemented: upgraded runtime target and SDK dependencies
  - `functions/package.json` updated to Node.js `22`
  - `firebase-functions` upgraded from `^4.7.0` to `^5.1.1` (compatibility-safe line)
  - `firebase-admin` aligned to `^12.7.0` for peer compatibility
  - Deployed and verified: all 3 functions running on Node.js 22 (1st Gen)

### Automated tests

Status: ✅ Completed

- [x] Unit tests for `AppointmentRequestService`
  - Added: `test/services/appointment_request_service_test.dart`
  - Covered: create, pending lookup, cancel(delete) behavior, non-pending cancel guard, cancelled-item stream filtering
- [x] Unit tests for `PushNotificationService`
  - Added: `test/services/push_notification_service_test.dart`
  - Covered: notification-enabled checks, save token, clear token, disable notifications
- [x] Integration test for full appointment flow
  - Added: `test/integration/appointment_flow_integration_test.dart`
  - Covered: create -> confirm -> link chat, create -> deny, create -> cancel(delete) with stream verification

### Email system

`TODO.md` lists email (SendGrid/SES) as in progress. Decide if push notifications replace that need or if email is still required for invites/onboarding.
