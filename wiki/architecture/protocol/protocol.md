---
type: Architecture
---

# Provisioning protocol

The [Pi service](../pi-container/pi-container.md) advertises BLE service `a0df0001-3d38-45b9-908f-a9ae97048720`. The Android/iOS app implements this protocol; browser previews remain simulated. No setup key, authentication exchange, or application-level encryption is used. Nearby BLE clients can send provisioning requests; installing this particular app is not an access control.

| UUID prefix | Access | Value |
| --- | --- | --- |
| `a0df0003` | Write with response | UTF-8 JSON request frames |
| `a0df0004` | Read | Pending byte or JSON response |

All characteristics use the service UUID suffix `-3d38-45b9-908f-a9ae97048720`.

1. Connect to the advertised service.
2. Encode the JSON request as UTF-8, at most 384 bytes. Each frame carries 1–19 payload bytes with a leading flag: `0` starts, `1` continues, and `2` finishes the message. Always use at least two frames, including for short requests. Write frames in order with ATT write responses.
3. Poll the response characteristic: a single byte `0` means pending. Byte `1` prefixes the completed UTF-8 JSON response. Read the complete characteristic value using long reads as needed.
4. Start another request with a new `0` frame. There is one Wi-Fi operation at a time; incomplete sessions and completed results expire after two minutes.

The previous setup-key client is incompatible: update both the app and Pi service together.

| Request | Successful response |
| --- | --- |
| `{"op":"scan"}` | First page of access points |
| `{"op":"page","index":1}` | A subsequent page from the last scan |
| `{"op":"connect","bssid":"00:11:22:33:44:55","password":"..."}` | `{"connected":true}` |

A scan page contains `networks` and `more`. Each access point has `ssid` as raw bytes encoded in hexadecimal, a lowercase `bssid`, `security` (`open`, `wpa2`, or `unsupported`), `signal` from 0 to 100, and `mhz`. Pages are zero-indexed with up to two entries each. The scan results are available for two minutes. Pass an empty password for open networks. WPA2-Personal accepts 8 to 63 printable ASCII characters or a 64-digit hexadecimal PSK. Hidden, enterprise, WEP, and WPA3-only networks are outside the current implementation.

A request can return `{"error":"..."}`. Error values include `scan_required`, `scan_timeout`, `network_unavailable`, `unsupported_security`, `invalid_password`, `activation_failed`, `activation_timeout`, `network_manager_error`, and `internal_error`. A completed connection indicates NetworkManager activation. Internet connectivity is independent.
