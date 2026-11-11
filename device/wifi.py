import re
import time
import uuid

import dbus

NM = "org.freedesktop.NetworkManager"
ROOT = "/org/freedesktop/NetworkManager"
PROPERTIES = "org.freedesktop.DBus.Properties"
WIRELESS = NM + ".Device.Wireless"
PSK = 0x100


class WifiError(Exception):
    pass


class Wifi:
    def __init__(self, bus: dbus.bus.BusConnection, interface: str) -> None:
        self.bus = bus
        self.manager = self.proxy(ROOT, NM)
        self.device = self.manager.GetDeviceByIpIface(interface, signature="s", timeout=5)
        self.wireless = self.proxy(self.device, WIRELESS)

    def proxy(self, path: str, interface: str) -> dbus.Interface:
        return dbus.Interface(self.bus.get_object(NM, path, introspect=False), interface)

    def get(self, path: str, interface: str, key: str):
        return self.proxy(path, PROPERTIES).Get(interface, key, signature="ss", timeout=5)

    def status(self) -> dict:
        if self.get(self.device, NM + ".Device", "State") != 100:
            return {"connected": False, "ssid": None, "bssid": None}
        path = self.get(self.device, WIRELESS, "ActiveAccessPoint")
        if path == "/":
            return {"connected": False, "ssid": None, "bssid": None}
        ap = self.proxy(path, PROPERTIES).GetAll(NM + ".AccessPoint", signature="s", timeout=5)
        return {
            "connected": True,
            "ssid": bytes(ap["Ssid"]).hex(),
            "bssid": str(ap["HwAddress"]).lower(),
        }

    def access_points(self):
        for path in self.wireless.GetAccessPoints(timeout=5, signature=""):
            ap = self.proxy(path, PROPERTIES).GetAll(NM + ".AccessPoint", signature="s", timeout=5)
            ssid = bytes(ap["Ssid"])
            if not ssid:
                continue
            security = "wpa2" if ap["RsnFlags"] & PSK else "unsupported"
            if not ap["Flags"] & 1 and not (ap["WpaFlags"] or ap["RsnFlags"]):
                security = "open"
            yield path, {
                "ssid": ssid.hex(),
                "bssid": str(ap["HwAddress"]).lower(),
                "security": security,
                "signal": int(ap["Strength"]),
                "mhz": int(ap["Frequency"]),
            }

    def scan(self) -> list[dict]:
        last_scan = self.get(self.device, WIRELESS, "LastScan")
        try:
            self.wireless.RequestScan({}, signature="a{sv}", timeout=5)
        except dbus.DBusException as error:
            if error.get_dbus_name() != NM + ".Device.NotAllowed" or last_scan < 0:
                raise
            # NetworkManager rate-limits scans, so use its existing results.
            return self.scan_results()

        deadline = time.monotonic() + 15
        while self.get(self.device, WIRELESS, "LastScan") == last_scan:
            if time.monotonic() >= deadline:
                raise WifiError("scan_timeout")
            time.sleep(0.25)

        return self.scan_results()

    def scan_results(self) -> list[dict]:
        return sorted(
            (ap for _, ap in self.access_points()),
            key=lambda ap: (-ap["signal"], ap["bssid"]),
        )

    def connect(self, bssid: str, password: str) -> None:
        match = next(
            ((path, ap) for path, ap in self.access_points() if ap["bssid"] == bssid),
            None,
        )

        if match is None:
            raise WifiError("network_unavailable")

        path, ap = match
        if ap["security"] == "unsupported":
            raise WifiError("unsupported_security")
        if ap["security"] == "open" and password:
            raise WifiError("invalid_password")
        if ap["security"] == "wpa2" and not valid_psk(password):
            raise WifiError("invalid_password")

        settings = {
            "connection": {
                "id": "rpi-wifi-link-" + bssid,
                "uuid": str(uuid.uuid4()),
                "type": "802-11-wireless",
                "autoconnect": True,
                "interface-name": str(self.get(self.device, NM + ".Device", "Interface")),
            },
            "802-11-wireless": {"ssid": dbus.ByteArray(bytes.fromhex(ap["ssid"]))},
            "ipv4": {"method": "auto"},
            "ipv6": {"method": "auto"},
        }

        if ap["security"] == "wpa2":
            settings["802-11-wireless-security"] = {
                "key-mgmt": "wpa-psk",
                "proto": dbus.Array(["rsn"], signature="s"),
                "psk": password,
            }

        checkpoint = self.manager.CheckpointCreate([self.device], 90, 2, signature="aouu", timeout=5)
        committed = False
        try:
            profile, active, _ = self.manager.AddAndActivateConnection2(
                settings,
                self.device,
                path,
                {"persist": "memory"},
                signature="a{sa{sv}}ooa{sv}",
                timeout=10,
            )

            self.wait_for_activation(active)
            self.proxy(profile, NM + ".Settings.Connection").Save(signature="", timeout=5)
            self.manager.CheckpointDestroy(checkpoint, signature="o", timeout=5)
            committed = True
        finally:
            if not committed:
                self.manager.CheckpointRollback(checkpoint, signature="o", timeout=5)

    def wait_for_activation(self, active: str) -> None:
        deadline = time.monotonic() + 45
        while time.monotonic() < deadline:
            state = self.get(active, NM + ".Connection.Active", "State")
            if state == 2:
                return
            if state >= 3:
                raise WifiError("activation_failed")
            time.sleep(0.5)

        raise WifiError("activation_timeout")


def valid_psk(password: str) -> bool:
    if re.fullmatch(r"[0-9a-fA-F]{64}", password):
        return True
    return 8 <= len(password) <= 63 and all(" " <= char <= "~" for char in password)
