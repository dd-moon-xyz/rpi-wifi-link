---
type: Architecture
---

# Mobile app

- Flutter and Dart: one Android/iOS codebase, intended for store publication.
- `flutter_reactive_ble`: discover the Pi and exchange JSON provisioning messages without a setup key.
- UI: view live Pi Wi-Fi status over BLE, choose a Pi, select Wi-Fi, enter credentials, and view the result.
- Configure platform-specific Bluetooth permissions and test on real Android and iOS devices.

Android/iOS use the real BLE service. Browser previews use simulated devices.

[Test the app](testing.md).
