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

Use `flutter devices` and `flutter run -d <device-id>` to test on a phone. iOS builds require macOS and Xcode.

Build an installable Android demo APK from `mobile/`:

```sh
flutter build apk --debug
```

Output: `mobile/build/app/outputs/flutter-apk/app-debug.apk` (relative to the repository root). This debug build is for testing, not store submission.
