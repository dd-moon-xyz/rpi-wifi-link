import json
import re
import time
from dataclasses import dataclass, field

SERVICE = "a0df0001-3d38-45b9-908f-a9ae97048720"
REQUEST = SERVICE.replace("0001-", "0003-")
RESPONSE = SERVICE.replace("0001-", "0004-")
MAX_REQUEST = 384
PAGE_SIZE = 2


class ProtocolError(Exception):
    pass


@dataclass
class Session:
    expires: float = field(default_factory=lambda: time.monotonic() + 120)
    buffer: bytearray | None = None
    response: bytes = b"\x00"
    used: bool = False
    pending: bool = False

    def write(self, packet: bytes) -> bytes | None:
        if self.used or not 2 <= len(packet) <= 20:
            raise ProtocolError("invalid frame")
        flag, payload = packet[0], packet[1:]
        if flag == 0:
            self.buffer = bytearray(payload)
            return None
        if flag not in (1, 2) or self.buffer is None:
            raise ProtocolError("missing initial frame")
        if len(self.buffer) + len(payload) > MAX_REQUEST:
            self.buffer = None
            raise ProtocolError("request too long")
        self.buffer.extend(payload)
        if flag == 1:
            return None
        message = bytes(self.buffer)
        self.buffer = None
        self.used = True
        return message


def unpack(message: bytes) -> dict:
    try:
        request = json.loads(message.decode("utf-8"))
    except (ValueError, RecursionError) as error:
        raise ProtocolError("invalid request") from error

    if not isinstance(request, dict):
        raise ProtocolError("invalid request")
    if request.get("op") == "scan" and request.keys() == {"op"}:
        return request
    if request.get("op") == "page" and request.keys() == {"op", "index"}:
        index = request["index"]
        if type(index) is int and 0 <= index < 256:
            return request
    if request.get("op") == "connect" and request.keys() == {"op", "bssid", "password"}:
        bssid, password = request["bssid"], request["password"]
        if isinstance(bssid, str) and isinstance(password, str) and len(password) <= 64:
            if re.fullmatch(r"(?:[0-9a-f]{2}:){5}[0-9a-f]{2}", bssid):
                return request
    raise ProtocolError("invalid request")


def pack(response: dict) -> bytes:
    return b"\x01" + json.dumps(response, separators=(",", ":")).encode("ascii")


def page(networks: list[dict], index: int) -> dict:
    start = index * PAGE_SIZE
    end = start + PAGE_SIZE
    return {"networks": networks[start:end], "more": end < len(networks)}
