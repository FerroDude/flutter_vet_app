# Deployment Guide — Peton Mobile (Flutter + Firebase)

This guide reflects the current app and Firestore schema used in the code.

## Prerequisites

- Flutter SDK (matching Dart `sdk: ^3.8.1`)
- Android Studio / Xcode (platform SDKs installed)
- Firebase project (Auth + Firestore enabled)

## Firebase Setup

1) Create a Firebase project and register Android and iOS apps.
2) Download and place config files:
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`
3) Run `flutterfire configure` (or ensure `lib/firebase_options.dart` matches your project).
4) Enable Authentication → Email/Password (require email verification).
5) Create Firestore database (Production or Test mode as needed).
6) Apply security rules aligned with the code (see `apps/mobile-flutter/firestore.rules`).

## Firestore Structure (as used by code)

- `users/{userId}`
  - `events/{eventId}` (appointments, medications, notes)
  - `clinicHistory/{historyId}`
- `clinics/{clinicId}`
  - `members/{userId}` (role, permissions)
- `chatRooms/{chatRoomId}`
  - `messages/{messageId}`

Notes:
- Clinics are discoverable by all signed‑in users (reads on `clinics` where `isActive == true`).
- 1:1 chat only (petOwnerId, vetId); no `participants` array.

## Security Rules

Use the rules in `apps/mobile-flutter/firestore.rules`. They:
- Allow users to manage their own profile and subcollections.
- Allow reading active clinics to support discovery; writes limited to clinic admins/app owner.
- Restrict chat room/message access to the room’s pet owner or vet.

## Local Build

Android:
- Debug: `flutter build apk --debug`
- Release: `flutter build apk --release`
- App Bundle: `flutter build appbundle --release`

iOS:
- From project root: `cd ios && pod install`
- Build: `flutter build ios --release`
- Archive and upload via Xcode.

## Notes & Known Limitations

- Local notifications are placeholders; do not expect real reminders until implemented.
- If you enable web builds, you’ll need separate hosting config; not covered here.

