---
type: Guide
---

# Install Android Studio on Ubuntu

```sh
sudo snap install android-studio --classic
```

Open Android Studio and complete the setup wizard to download the Android SDK. No new project is needed.

Install the command-line tools:

1. Open **Settings → Languages & Frameworks → Android SDK**.
2. Select the **SDK Tools** tab.
3. Check **Android SDK Command-line Tools (latest)**.
4. Click **Apply**, confirm with **OK**, and wait for installation to finish.

Verify the setup:

```sh
flutter doctor
```

If it reports no issues, setup is complete. If it reports unaccepted Android licenses, run the following, review and accept the licenses you agree to, then rerun `flutter doctor`:

```sh
flutter doctor --android-licenses
```

[Android Studio on Snapcraft](https://snapcraft.io/android-studio) · [Flutter Android setup](https://docs.flutter.dev/platform-integration/android/setup)
