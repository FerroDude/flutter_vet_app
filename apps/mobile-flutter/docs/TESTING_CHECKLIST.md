# Testing Checklist

## Priority Testing Tasks

### 1. Push Notifications Testing

#### Prerequisites

- [ ] Deploy Cloud Functions: `firebase deploy --only functions`
- [ ] Ensure FCM is configured for both Android and iOS
- [ ] Test on physical devices (emulators don't receive push notifications)

#### Appointment Request Notifications

| Scenario                | Trigger                   | Expected Recipient            | Expected Message                                      |
| ----------------------- | ------------------------- | ----------------------------- | ----------------------------------------------------- |
| New appointment request | Pet owner submits request | Clinic receptionists + admins | "New Appointment Request" with pet owner and pet name |
| Appointment confirmed   | Receptionist confirms     | Pet owner                     | "Appointment Confirmed!"                              |
| Appointment denied      | Receptionist denies       | Pet owner                     | "Appointment Request Update"                          |

**Test Steps:**

1. [ ] Log in as pet owner on Device A
2. [ ] Log in as receptionist on Device B
3. [ ] Pet owner creates appointment request
4. [ ] Verify receptionist receives push notification
5. [ ] Receptionist confirms the appointment
6. [ ] Verify pet owner receives confirmation notification
7. [ ] Repeat with denial flow

#### Chat Request Notifications

- [ ] Test new chat request notification to clinic staff
- [ ] Test chat message notifications

#### Notification Settings

- [ ] Toggle notifications OFF in Settings, verify no notifications received
- [ ] Toggle notifications ON, verify notifications resume
- [ ] Test across all user roles (pet owner, vet, receptionist, clinic admin)

---

### 2. Appointment Request Flow Testing

#### Pet Owner Flow

**Creating a Request:**

- [ ] Navigate to Clinic tab
- [ ] Tap FAB (when on Appointments filter) or "Request Appointment" option
- [ ] Select a pet from the list
- [ ] Choose preferred date range (start and end date)
- [ ] Select time preference (Morning/Afternoon/Evening/Flexible)
- [ ] Add reason/notes (optional)
- [ ] Submit request
- [ ] Verify request appears in Clinic tab under Appointments filter
- [ ] Verify request shows "Pending" status

**Viewing Requests:**

- [ ] Filter to "Appointments" - only appointment requests shown
- [ ] Filter to "Chats" - only chat conversations shown
- [ ] Filter to "All" - both types shown, sorted by date
- [ ] Search functionality works across appointment reasons

**Cancelling a Request:**

- [ ] Long press on pending request
- [ ] Confirm cancellation
- [ ] Verify request is deleted (not visible anywhere)

#### Receptionist Flow

**Viewing Requests:**

- [ ] Navigate to Clinic tab
- [ ] Verify pending appointments show with badge count
- [ ] Filter chips show correct counts for pending items

**Confirming an Appointment:**

- [ ] Tap on pending appointment request
- [ ] View appointment details (pet, owner, date range, time preference, reason)
- [ ] Tap "Confirm" button
- [ ] Optionally add response message
- [ ] Submit confirmation
- [ ] Verify status changes to "Confirmed"
- [ ] Verify pet owner sees updated status

**Denying an Appointment:**

- [ ] Tap on pending appointment request
- [ ] Tap "Deny" button
- [ ] Add reason for denial (required or optional?)
- [ ] Submit denial
- [ ] Verify status changes to "Denied"
- [ ] Verify pet owner sees updated status with reason

**Starting Chat from Appointment:**

- [ ] On pending or confirmed appointment, tap "Chat" action
- [ ] Verify chat room opens or is created
- [ ] Verify no permission errors (was previously PERMISSION_DENIED issue)

#### Edge Cases

- [ ] Pet owner with no pets tries to request appointment
- [ ] Pet owner cancels while receptionist is viewing
- [ ] Multiple receptionists viewing same request
- [ ] Request with very long reason text
- [ ] Offline behavior when creating/updating requests

---

### 3. Unified Clinic Tab Testing

#### Pet Owner Clinic Tab

- [ ] Default view shows "All" items
- [ ] FAB shows both options on "All" filter
- [ ] FAB shows single "New Chat" on "Chats" filter
- [ ] FAB shows single "Request Appointment" on "Appointments" filter
- [ ] Empty states display correctly for each filter
- [ ] Badges update in real-time

#### Receptionist Clinic Tab

- [ ] Pending items appear at top of list
- [ ] Badge counts on filter chips are accurate
- [ ] "Accept Chat Request" button works for pending chats
- [ ] Appointment action buttons (Deny/Chat/Confirm) work correctly
- [ ] Search filters both chats and appointments

---

### 4. Firestore Security Rules Testing

- [ ] Pet owner can only see their own appointment requests
- [ ] Pet owner cannot see other users' requests
- [ ] Receptionist can see all clinic appointment requests
- [ ] Receptionist can update appointment status
- [ ] Receptionist can read all chat rooms for their clinic
- [ ] Receptionist can read/write messages in clinic chats
- [ ] Non-clinic members cannot access clinic data

---

### 5. Regression Testing

After all new features work:

- [ ] Existing chat functionality still works
- [ ] Vet chat functionality unaffected
- [ ] Clinic admin dashboard still works
- [ ] Pet owner dashboard displays correctly (no appointment section)
- [ ] All navigation flows work correctly
- [ ] No console errors or warnings

---

## Known Issues to Watch

1. **Cancelled appointments visibility** - Old cancelled documents should be filtered out, but verify no leaks
2. **Permission errors** - Watch for PERMISSION_DENIED in logs when opening chats
3. **Provider context** - Ensure no "Could not find Provider" errors when navigating

---

## Test Accounts Needed

| Role         | Purpose                                            |
| ------------ | -------------------------------------------------- |
| Pet Owner    | Create appointment requests, receive notifications |
| Receptionist | Manage requests, accept chats                      |
| Clinic Admin | Verify admin functions still work                  |
| Vet          | Verify vet functions unaffected                    |

---

## Deployment Checklist

Before release:

- [ ] Deploy Firestore indexes: `firebase deploy --only firestore:indexes`
- [ ] Deploy Firestore rules: `firebase deploy --only firestore:rules`
- [ ] Deploy Cloud Functions: `firebase deploy --only functions`
- [ ] Test on Android device
- [ ] Test on iOS device (if applicable)
