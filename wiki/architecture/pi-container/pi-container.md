---
type: Architecture
status: proposed
---

# Pi container

- Lightweight Docker service on Raspberry Pi OS Lite; language and framework undecided.
- Target Pi 4, Pi 5, and Zero 2 W with a common 64-bit image; keep memory use low.
- Access host BlueZ for BLE and host NetworkManager for Wi-Fi through explicitly authorized D-Bus interfaces.
- Installer or prepared SD-card image installs host dependencies and starts the container on boot; no desktop required.
- Support the Zero 2 W's 2.4 GHz Wi-Fi limitation.
