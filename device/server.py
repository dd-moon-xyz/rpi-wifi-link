import logging
import os
import signal
import time
from concurrent.futures import Future, ThreadPoolExecutor
from contextlib import closing

import dbus
import dbus.service
from dbus.mainloop import NULL_MAIN_LOOP
from dbus.mainloop.glib import DBusGMainLoop, threads_init
from gi.repository import GLib

import protocol
from wifi import Wifi, WifiError

BLUEZ = "org.bluez"
PROPERTIES = "org.freedesktop.DBus.Properties"
OBJECT_MANAGER = "org.freedesktop.DBus.ObjectManager"
SERVICE = BLUEZ + ".GattService1"
CHARACTERISTIC = BLUEZ + ".GattCharacteristic1"
ADVERTISEMENT = BLUEZ + ".LEAdvertisement1"
ROOT = "/org/rpiwifilink"
SERVICE_PATH = ROOT + "/service0"


class GattError(dbus.DBusException):
    def __init__(self, name: str) -> None:
        super().__init__(name=BLUEZ + ".Error." + name)


class Provisioner:
    def __init__(self, interface: str) -> None:
        self.interface = interface
        self.sessions: dict[str, protocol.Session] = {}
        self.executor = ThreadPoolExecutor(max_workers=1)
        self.networks: list[dict] = []
        self.scan_time = 0.0
        self.busy = False

    def session(self, device: str, renew: bool = False) -> protocol.Session:
        now = time.monotonic()
        self.sessions = {
            peer: session for peer, session in self.sessions.items()
            if session.pending or session.expires > now
        }

        session = self.sessions.get(device)
        if renew and session and session.used and not session.pending:
            session = None
        if session is None and renew:
            if device not in self.sessions and len(self.sessions) >= 32:
                raise GattError("InProgress")
            session = self.sessions[device] = protocol.Session()
        if session is None:
            raise GattError("Failed")
        return session

    def write(self, device: str, packet: bytes) -> None:
        session = self.session(device, renew=bool(packet) and packet[0] == 0)
        if self.busy:
            raise GattError("InProgress")
        try:
            message = session.write(packet)
            if message is None:
                return
            request = protocol.unpack(message)
        except protocol.ProtocolError:
            raise GattError("Failed") from None

        self.busy = session.pending = True
        work = self.executor.submit(self.execute, request)
        work.add_done_callback(lambda result: GLib.idle_add(self.complete, session, result))

    def execute(self, request: dict) -> dict:
        try:
            if request["op"] == "page":
                if time.monotonic() - self.scan_time > 120:
                    return {"error": "scan_required"}
                return protocol.page(self.networks, request["index"])

            with closing(dbus.SystemBus(private=True, mainloop=NULL_MAIN_LOOP)) as bus:
                bus.set_exit_on_disconnect(False)
                wifi = Wifi(bus, self.interface)
                if request["op"] == "scan":
                    self.networks = wifi.scan()[:256 * protocol.PAGE_SIZE]
                    self.scan_time = time.monotonic()
                    return protocol.page(self.networks, 0)

                wifi.connect(request["bssid"], request["password"])
                return {"connected": True}
        except WifiError as error:
            return {"error": str(error)}
        except dbus.DBusException as error:
            logging.warning("NetworkManager operation failed (%s)", error.get_dbus_name())
            return {"error": "network_manager_error"}

    def complete(self, session: protocol.Session, result: Future) -> bool:
        try:
            session.response = protocol.pack(result.result())
        except Exception:
            logging.error("Unexpected provisioning error")
            session.response = protocol.pack({"error": "internal_error"})
        finally:
            session.pending = self.busy = False
            session.expires = time.monotonic() + 120
        return GLib.SOURCE_REMOVE


class Object(dbus.service.Object):
    def __init__(self, bus, path: str, interface: str, properties: dict) -> None:
        super().__init__(bus, path)
        self.path = dbus.ObjectPath(path)
        self.interface = interface
        self.properties = properties

    @dbus.service.method(PROPERTIES, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        if interface != self.interface:
            raise GattError("NotSupported")
        return self.properties


class Characteristic(Object):
    def __init__(self, bus, index: int, uuid: str, flag: str, provisioner: Provisioner) -> None:
        super().__init__(bus, f"{SERVICE_PATH}/char{index}", CHARACTERISTIC, {
            "UUID": uuid,
            "Service": dbus.ObjectPath(SERVICE_PATH),
            "Flags": dbus.Array([flag], signature="s"),
        })

        self.uuid = uuid
        self.provisioner = provisioner

    @dbus.service.method(CHARACTERISTIC, in_signature="a{sv}", out_signature="ay")
    def ReadValue(self, options):
        offset = options.get("offset", 0)
        device = self.peer(options)
        if self.uuid != protocol.RESPONSE:
            raise GattError("NotPermitted")
        value = self.provisioner.session(device).response
        if offset > len(value):
            raise GattError("InvalidOffset")
        return dbus.ByteArray(value[offset:])

    @dbus.service.method(CHARACTERISTIC, in_signature="aya{sv}", byte_arrays=True)
    def WriteValue(self, value, options):
        if self.uuid != protocol.REQUEST or options.get("prepare-authorize") or options.get("offset", 0):
            raise GattError("NotPermitted")
        self.provisioner.write(self.peer(options), bytes(value))

    @staticmethod
    def peer(options) -> str:
        device = options.get("device")
        if not device:
            raise GattError("Failed")
        return str(device)


class Application(dbus.service.Object):
    def __init__(self, bus, provisioner: Provisioner) -> None:
        super().__init__(bus, ROOT)
        self.objects = [
            Object(bus, SERVICE_PATH, SERVICE, {"UUID": protocol.SERVICE, "Primary": True}),
            Characteristic(bus, 1, protocol.REQUEST, "write", provisioner),
            Characteristic(bus, 2, protocol.RESPONSE, "read", provisioner),
        ]

    @dbus.service.method(OBJECT_MANAGER, out_signature="a{oa{sa{sv}}}")
    def GetManagedObjects(self):
        return {item.path: {item.interface: item.properties} for item in self.objects}


class Advertisement(Object):
    @dbus.service.method(ADVERTISEMENT)
    def Release(self):
        pass


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    DBusGMainLoop(set_as_default=True)
    threads_init()
    bus = dbus.SystemBus()
    loop = GLib.MainLoop()
    GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, loop.quit)
    provisioner = Provisioner(os.environ.get("WIFI_INTERFACE", "wlan0"))
    adapter = bus.get_object(BLUEZ, "/org/bluez/" + os.environ.get("BLE_ADAPTER", "hci0"), introspect=False)
    app = Application(bus, provisioner)
    advert = Advertisement(bus, "/org/rpiwifilink_advert", ADVERTISEMENT, {
        "Type": "peripheral",
        "ServiceUUIDs": dbus.Array([protocol.SERVICE], signature="s"),
    })

    startup_failed = False

    def registration_failed(error) -> None:
        nonlocal startup_failed
        startup_failed = True
        logging.error("BlueZ registration failed (%s)", error.get_dbus_name())
        loop.quit()

    def service_registered() -> None:
        adapter.RegisterAdvertisement(
            advert.path, {}, dbus_interface=BLUEZ + ".LEAdvertisingManager1", signature="oa{sv}",
            reply_handler=lambda: logging.info("BLE provisioning available"), error_handler=registration_failed,
        )

    def bluez_owner_changed(name, old_owner, new_owner) -> None:
        if old_owner:
            logging.warning("BlueZ restarted")
            loop.quit()

    bus.add_signal_receiver(
        bluez_owner_changed, signal_name="NameOwnerChanged", dbus_interface="org.freedesktop.DBus",
        bus_name="org.freedesktop.DBus", arg0=BLUEZ,
    )

    adapter.RegisterApplication(
        dbus.ObjectPath(ROOT), {}, dbus_interface=BLUEZ + ".GattManager1", signature="oa{sv}",
        reply_handler=service_registered, error_handler=registration_failed,
    )

    loop.run()
    provisioner.executor.shutdown(wait=True)
    if startup_failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
