---
type: Architecture
status: proposed
---

# Provisioning protocol

- Versioned BLE messages shared by the [mobile app](../mobile-app/mobile-app.md) and [Pi container](../pi-container/pi-container.md).
- Flow: discover → authenticate → scan networks → select network → send credentials → confirm connection.
- Protect credentials and restrict provisioning to authorized users; authentication details remain undecided.
- Failed setup allows retry over BLE without existing Wi-Fi or internet.
