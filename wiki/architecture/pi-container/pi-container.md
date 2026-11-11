---
type: Architecture
---

# Pi container

The Python service in `device/` targets Raspberry Pi OS Lite 64-bit Trixie on the Pi 4, Pi 5, and Zero 2 W. The same ARM64 image uses the host's BlueZ and NetworkManager services over the system D-Bus socket. It needs no desktop, container network, or direct radio device access. The Zero 2 W scans with its own 2.4 GHz radio and lists only access points it can detect.

## Install on Trixie

Docker Engine with the Compose plugin, BlueZ, and NetworkManager must be installed. The Docker, Bluetooth, and NetworkManager services must be running. The Wi-Fi adapter must be managed by NetworkManager, and Bluetooth must be powered on. Run from the repository root:

```sh
sudo sh deploy/install.sh
sudo docker compose logs rpi-wifi-link
```

The installer builds and starts the Compose service. The service restarts with Docker. Use `sudo docker compose up -d` from the repository root to start it again. The container uses `wlan0` and `hci0` by default. To select other interfaces, pass `WIFI_INTERFACE` and `BLE_ADAPTER` in the installer's environment.

No setup key is generated, mounted, or requested. The [mobile app](../mobile-app/mobile-app.md) connects directly using the [BLE protocol](../protocol/protocol.md). Existing setup-key files from older installations are unused.

The service advertises the Pi's hostname (for example, `POR`) as its Bluetooth device name. Compose mounts the host's `/etc/hostname` read-only so the container uses the Pi's name. Restart the service after renaming the Pi. BlueZ may shorten long names to fit the advertising packet.

A successful activation saves a NetworkManager profile. Failed activations roll back to the previous Wi-Fi configuration. Use a local console or Ethernet for the first live test because a successful provision changes the Wi-Fi connection.

## Bluetooth registration failure

If logs repeat `BlueZ registration failed (org.bluez.Error.Failed)`, check the host:

```sh
bluetoothctl show
```

`Powered: no` with `PowerState: off-blocked` can indicate a software-blocked radio. Find the Bluetooth rfkill entry (`name` is `hci0`) and check its block flags:

```sh
for item in /sys/class/rfkill/*; do
  echo "$item"
  cat "$item/name" "$item/soft" "$item/hard"
done
```

For `hci0`, `soft` equal to `1` and `hard` equal to `0` confirms a software block. On CLAX and BRIX this was `rfkill0`; substitute the matching entry on other hosts:

```sh
echo 0 | sudo tee /sys/class/rfkill/rfkill0/soft
sudo bluetoothctl power on
sudo docker restart rpi-wifi-link
```

Verify `bluetoothctl show` reports `Powered: yes` and an active advertising instance, and `sudo docker logs --tail 20 rpi-wifi-link` reports `BLE provisioning available as <hostname>`. If the radio is already powered on, investigate the Bluetooth service logs instead: `sudo journalctl -u bluetooth -n 50 --no-pager`.
