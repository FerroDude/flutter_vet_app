### iOS setup guide (run Peton on iOS)

This checklist is for when you have access to a Mac. It assumes the Flutter app lives at `apps/mobile-flutter/`.

### Prerequisites

- Mac running recent macOS
- Xcode (15+ recommended) from the App Store
- Apple ID (free is fine for simulator; paid dev account needed for TestFlight/App Store)
- Flutter SDK installed and on PATH
- CocoaPods installed (`brew install cocoapods` or `sudo gem install cocoapods`)

### Verify the toolchain

```bash
flutter doctor -v
xcodebuild -version
pod --version
```

Fix any issues reported by `flutter doctor`.

### Prepare the project

```bash
cd apps/mobile-flutter
flutter pub get
cd ios
pod install
```

Open the workspace in Xcode:

```bash
open Runner.xcworkspace
```

### Configure signing (Xcode)

In Xcode → `Runner` project → `Runner` target → `Signing & Capabilities`:

- Set your Team
- Ensure the Bundle Identifier (current: `on.pet.peton`)

Notes:

- If you change the Bundle ID, update the iOS app in Firebase and download a new `GoogleService-Info.plist`.
- Simulator runs work without a paid dev account; real device/TestFlight requires proper provisioning.

### Firebase and Google Sign‑In (iOS)

- Ensure `apps/mobile-flutter/ios/Runner/GoogleService-Info.plist` exists in the Xcode project and is included in the `Runner` target.
- Add URL Type for Google Sign‑In:
  1. Xcode → `Runner` target → `Info` tab
  2. Add a new `URL Type`
  3. Set `URL Schemes` to the `REVERSED_CLIENT_ID` from `GoogleService-Info.plist`

### Run on iOS Simulator

```bash
cd apps/mobile-flutter
flutter run -d ios
```

Or press Run in Xcode with an iOS Simulator selected.

### Common build commands

```bash
# Debug run on simulator
flutter run -d ios

# Build for iOS simulator (artifact for CI/device labs)
flutter build ios --simulator

# Build signed IPA for devices/TestFlight (requires signing)
flutter build ipa
```

### Troubleshooting

- Pods/linking issues:
  - `sudo gem install cocoapods`
  - `pod repo update`
  - `cd ios && pod install --repo-update`
- Xcode toolchain:
  - Xcode → Settings → Locations → Command Line Tools set to your Xcode
- Provisioning/signing:
  - Set Team, use a unique Bundle ID, ensure certificates/profiles for distribution
- Firebase mismatch:
  - `GoogleService-Info.plist` must match your Bundle ID and Firebase iOS app

### Windows-only note

You cannot run the iOS Simulator on Windows. Use a Mac (local or remote) to follow these steps. For non‑interactive checks, use macOS CI to build `flutter build ios --simulator` and upload to a device lab.
