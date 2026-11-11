---
type: Guide
---

# Install Flutter on Ubuntu

```sh
sudo snap install flutter --classic
```

After installation, run this check to verify Flutter and identify any missing development tools. Wait for the first-run SDK download to finish:

```sh
flutter doctor
```

For browser development, Android Studio and the Android SDK are not required locally. Android-related `flutter doctor` warnings can be ignored; GitHub Actions supplies those tools for Android builds.

[Flutter on Snapcraft](https://snapcraft.io/flutter)

Next: [Run and test the UI](../../architecture/mobile-app/testing.md).
