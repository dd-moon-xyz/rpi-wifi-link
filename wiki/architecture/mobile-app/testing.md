---
type: Guide
---

# Test the UI

The Flutter prototype uses simulated devices and networks. No Bluetooth, Raspberry Pi, or Wi-Fi connection is required. Credentials are held temporarily in memory and cleared after the simulated connection.

With the Flutter SDK installed, run from the repository root:

```sh
cd mobile
flutter pub get
dart format lib test
flutter analyze
flutter test test/setup_test.dart
flutter run -d chrome
```

Platform scaffolding is included in the repository.

Choose a Pi and network, enter at least eight characters, and connect. The interface uses realistic wording, but connections remain simulated. Automated tests exercise success and failure; the failure control is not shown in the UI. This prototype does not implement device authentication or real provisioning.

Builds run in GitHub Actions without a local Android SDK or Mac. Push changes under `mobile/`, or manually run **Build Android** or **Build iOS** from the repository’s **Actions** tab.

Download `rpi-wifi-link-android-debug` from the completed Android run’s artifacts for an installable test APK. This debug build is not for store submission.

The iOS workflow produces `rpi-wifi-link-ios-unsigned`; Apple signing is required before installation on an iPhone.
