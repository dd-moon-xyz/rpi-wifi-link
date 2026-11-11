---
type: Architecture
---

# Provisioning protocol

The [Pi service](../pi-container/pi-container.md) advertises BLE service `a0df0001-3d38-45b9-908f-a9ae97048720`. The Flutter app currently simulates setup. A compatible client needs the Pi's private 32-byte setup key decoded from hexadecimal.

| UUID prefix | Access | Value |
| --- | --- | --- |
| `a0df0002` | Read | 16-byte one-use challenge |
| `a0df0003` | Write with response | Request frames |
| `a0df0004` | Read | Pending byte or encrypted response |

All characteristics use the service UUID suffix `-3d38-45b9-908f-a9ae97048720`.

1. Connect to the advertised service and read the challenge.
2. Encrypt the UTF-8 JSON request with AES-256-GCM. Generate a fresh random 12-byte nonce. The additional authenticated data is the ASCII string `rpi-wifi-link/v1/request/` followed by the raw challenge. Concatenate the nonce, ciphertext, and 16-byte tag.
3. Split this envelope into payloads of 1 to 19 bytes. Prefix the first payload with byte `0`, intermediate payloads with byte `1`, and the final payload with byte `2`. Write each frame in order with an ATT write request. The envelope limit is 384 bytes.
4. Poll the response characteristic. A single byte `0` means the operation is pending. Byte `1` prefixes a completed envelope with the same nonce, ciphertext, and tag layout. Read the complete characteristic value using long reads as needed, then decrypt with additional authenticated data `rpi-wifi-link/v1/response/` followed by the original challenge. Read a new challenge after retrieving the response to start the next operation.

Challenges and results expire after two minutes after issuance and completion respectively. The final frame consumes the challenge even if authentication fails. There is one Wi-Fi operation at a time. An ATT in-progress error means the client can retry the frame after the current operation finishes.

| Request | Successful response |
| --- | --- |
| `{"op":"scan"}` | First page of access points |
| `{"op":"page","index":1}` | A subsequent page from the last scan |
| `{"op":"connect","bssid":"00:11:22:33:44:55","password":"..."}` | `{"connected":true}` |

A scan page contains `networks` and `more`. Each access point has `ssid` as raw bytes encoded in hexadecimal, a lowercase `bssid`, `security` (`open`, `wpa2`, or `unsupported`), `signal` from 0 to 100, and `mhz`. Pages are zero-indexed with up to two entries each. The scan results are available for two minutes. Pass an empty password for open networks. WPA2-Personal accepts 8 to 63 printable ASCII characters or a 64-digit hexadecimal PSK. Hidden, enterprise, WEP, and WPA3-only networks are outside the current implementation.

An authenticated request can return `{"error":"..."}`. Error values include `scan_required`, `scan_timeout`, `network_unavailable`, `unsupported_security`, `invalid_password`, `activation_failed`, `activation_timeout`, `network_manager_error`, and `internal_error`. A completed connection indicates NetworkManager activation. Internet connectivity is independent.
