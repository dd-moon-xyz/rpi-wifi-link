---
type: Guide
---

# Test the UI

Android/iOS discover real Pis over Bluetooth. The browser preview uses simulated devices and networks; no Pi is needed for browser UI tests. Wi-Fi passwords are cleared after each attempt.

For a local browser preview, run from the repository root:

```sh
cd mobile
flutter pub get
dart format lib test
flutter analyze
flutter run -d chrome
```

Platform scaffolding is included in the repository.

Choose a Pi and network, enter the Wi-Fi password, and connect. Browser connections remain simulated. Automated tests exercise UI success/failure and request framing and response handling.

Automated mobile tests and Android builds run only in GitHub Actions. Do not run local Android builds, emulator tests, or SDK commands. No local Android SDK or Mac is required. Push changes under `mobile/`, or manually run **Build Android** or **Build iOS** from the repository’s **Actions** tab.

Successful builds on `main` share a GitHub release named `build-<commit-sha>`, with `rpi-wifi-link.apk` from Android and `rpi-wifi-link.ipa` from iOS. Each file appears after its platform workflow succeeds. Changes to either mobile workflow trigger both builds. [Download the latest APK directly](https://github.com/dd-moon-xyz/rpi-wifi-link/releases/latest/download/rpi-wifi-link.apk), or browse [Releases](https://github.com/dd-moon-xyz/rpi-wifi-link/releases). The APK needs no archive extraction and is a debug build for testing, not store submission. [Download the latest IPA](https://github.com/dd-moon-xyz/rpi-wifi-link/releases/latest/download/rpi-wifi-link.ipa). The App Store-signed IPA still requires TestFlight for iPhone installation.

Pull requests and other branches only save `rpi-wifi-link-android-debug` as an Actions artifact; they do not publish releases. Release uploads use the workflow’s built-in GitHub token, with write access limited to the release job.

On `main`, the iOS workflow signs `xyz.ddmoon.rpiwifilink` for team `F74L6933DL`, saves `rpi-wifi-link-ios-signed`, and uploads it to App Store Connect for TestFlight. The existing `internal` group has Apple's automatic distribution enabled (`hasAccessToAllBuilds=true`), so processed, compliant builds become available to that group automatically. Do not pass `--beta-group internal` to the upload tool: Apple rejects explicit build assignment to this internal group. Install or update using the TestFlight app. The workflow does not submit a public App Store release or external beta review.

`Info.plist` declares `ITSAppUsesNonExemptEncryption=false`: the current app has no custom encryption library or non-exempt encryption. This declaration avoids the repeated export-compliance questionnaire for new builds. Reassess it if encryption is added. Older builds retain their own compliance state. [Apple's declaration reference](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption).

Required repository Actions secrets:

- `APP_STORE_CONNECT_API_KEY`: complete contents of the downloaded `.p8` API key.
- `IOS_DISTRIBUTION_PRIVATE_KEY`: complete PEM contents of `.secrets/ios-distribution-key.pem`.

The non-secret Key ID and Issuer ID are configured directly in the workflow. Existing GitHub secrets for those IDs are unused. The API key authenticates Apple requests; the separate RSA key signs the distribution certificate. The workflow creates or reuses a matching distribution certificate and App Store profile. Keep the same RSA key for subsequent builds to avoid creating a new certificate every run. Keep `.secrets/` private and backed up; never commit its files. Signing uses Codemagic’s open-source CLI tools on GitHub’s Mac runner, without a Codemagic account.

Pull requests and non-`main` builds remain unsigned, produce `rpi-wifi-link-ios-unsigned`, and do not receive signing secrets. A signed App Store IPA is installed through TestFlight, not directly like an Android APK. Re-running an already uploaded build can require a new workflow run number. [Signing tool reference](https://github.com/codemagic-ci-cd/cli-tools/blob/v0.70.2/docs/app-store-connect/fetch-signing-files.md).

For a live test, install the Android APK on a Bluetooth-capable phone, enable Bluetooth, and grant the requested permissions (older Android versions also require location services). Select the Pi to scan networks directly, without a setup key. Choose a scanned WPA2-Personal or open network and connect. Unsupported security is not selectable. Open networks do not require a password.

The device list queries each discovered Pi’s live NetworkManager status over Bluetooth after discovery. Refresh clears old readings and queries again, so connections changed outside the app are reflected. Devices show `connected` or `disconnected` from that reading, `checking...` while pending, or `wifi status unavailable` if the query fails. Device selection is briefly disabled while status requests use the Bluetooth connection. A successful result confirms Wi-Fi activation, not internet access. Real-radio Android/iOS testing is still required; a cloud build alone cannot verify Bluetooth behavior.

Connection and scan errors include their stage (`bluetooth connection`, `wifi status`, `wifi scan`, or `wifi confirmation`) and the underlying platform/device message. Wi-Fi passwords are redacted from confirmation errors. A confirmation error alone does not prove that Wi-Fi activation failed; check the Pi’s connection state before retrying a network change.
