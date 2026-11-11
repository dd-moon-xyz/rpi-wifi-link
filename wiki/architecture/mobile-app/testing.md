---
type: Guide
---

# Test the UI

Android/iOS discover real Pis over Bluetooth. The browser preview uses simulated devices and networks; no Pi is needed for browser UI tests. Wi-Fi passwords are cleared after each attempt. Setup keys remain in memory only and are cleared after connecting or leaving setup.

For a local browser preview, run from the repository root:

```sh
cd mobile
flutter pub get
dart format lib test
flutter analyze
flutter run -d chrome
```

Platform scaffolding is included in the repository.

Choose a Pi and network, enter the Wi-Fi password, and connect. Browser connections remain simulated. Automated tests exercise UI success/failure and encrypted protocol compatibility.

Automated mobile tests and Android builds run only in GitHub Actions. Do not run local Android builds, emulator tests, or SDK commands. No local Android SDK or Mac is required. Push changes under `mobile/`, or manually run **Build Android** or **Build iOS** from the repository’s **Actions** tab.

Download `rpi-wifi-link-android-debug` from the completed Android run’s artifacts for an installable test APK. This debug build is not for store submission.

On `main`, the iOS workflow signs `xyz.ddmoon.rpiwifilink` for team `F74L6933DL`, saves `rpi-wifi-link-ios-signed`, and uploads it to App Store Connect for TestFlight. It does not submit a public App Store release or external beta review. After Apple processes the build, add it to an internal TestFlight group and install using the TestFlight app. Complete any export-compliance questions Apple presents for this app’s encryption.

Required repository Actions secrets:

- `APP_STORE_CONNECT_API_KEY`: complete contents of the downloaded `.p8` API key.
- `IOS_DISTRIBUTION_PRIVATE_KEY`: complete PEM contents of `.secrets/ios-distribution-key.pem`.

The non-secret Key ID and Issuer ID are configured directly in the workflow. Existing GitHub secrets for those IDs are unused. The API key authenticates Apple requests; the separate RSA key signs the distribution certificate. The workflow creates or reuses a matching distribution certificate and App Store profile. Keep the same RSA key for subsequent builds to avoid creating a new certificate every run. Keep `.secrets/` private and backed up; never commit its files. Signing uses Codemagic’s open-source CLI tools on GitHub’s Mac runner, without a Codemagic account.

Pull requests and non-`main` builds remain unsigned, produce `rpi-wifi-link-ios-unsigned`, and do not receive signing secrets. A signed App Store IPA is installed through TestFlight, not directly like an Android APK. Re-running an already uploaded build can require a new workflow run number. [Signing tool reference](https://github.com/codemagic-ci-cd/cli-tools/blob/v0.70.2/docs/app-store-connect/fetch-signing-files.md).

For a live test, install the Android APK on a Bluetooth-capable phone, enable Bluetooth, and grant the requested permissions (older Android versions also require location services). Select the Pi and enter its private 64-character setup key from `/etc/rpi-wifi-link/setup-key`. Choose a scanned WPA2-Personal or open network and connect. Unsupported security is not selectable. Open networks do not require a password.

The existing service does not expose Wi-Fi status before provisioning, so the device list shows `wifi status unavailable` rather than a guessed connection state. A successful result confirms NetworkManager activation, not internet access. Real-radio Android/iOS testing is still required; a cloud build alone cannot verify Bluetooth behavior.
