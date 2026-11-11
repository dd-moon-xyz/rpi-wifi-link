import json
import unittest

import protocol


class ProtocolTests(unittest.TestCase):
    def test_accepts_live_status_request(self):
        self.assertEqual(protocol.unpack(b'{"op":"status"}'), {"op": "status"})

    def test_short_scan_uses_initial_and_final_frames(self):
        session = protocol.Session()
        self.assertIsNone(session.write(b'\x00{"op":"scan"'))
        self.assertEqual(protocol.unpack(session.write(b'\x02}')), {"op": "scan"})
        self.assertTrue(session.used)

    def test_split_connect_request_preserves_json(self):
        request = {"op": "connect", "bssid": "00:11:22:33:44:55", "password": "test-password"}
        message = json.dumps(request, separators=(",", ":")).encode()
        session = protocol.Session()
        self.assertIsNone(session.write(b"\x00" + message[:19]))
        for offset in range(19, len(message) - 19, 19):
            self.assertIsNone(session.write(b"\x01" + message[offset:offset + 19]))

        final_offset = 19 * ((len(message) - 1) // 19)
        result = session.write(b"\x02" + message[final_offset:])
        self.assertEqual(protocol.unpack(result), request)

    def test_rejects_final_frame_without_initial_frame(self):
        with self.assertRaises(protocol.ProtocolError):
            protocol.Session().write(b"\x02}")

    def test_rejects_reusing_a_completed_request(self):
        session = protocol.Session()
        session.write(b'\x00{"op":"scan"')
        session.write(b'\x02}')
        with self.assertRaises(protocol.ProtocolError):
            session.write(b'\x00{')

    def test_rejects_invalid_requests(self):
        for message in (b"not json", b"[]", b'{"op":"page","index":true}', b'{"op":"scan","extra":1}'):
            with self.subTest(message=message):
                with self.assertRaises(protocol.ProtocolError):
                    protocol.unpack(message)

    def test_response_has_completion_marker_and_json(self):
        result = protocol.pack({"connected": True})
        self.assertEqual(result[0], 1)
        self.assertEqual(json.loads(result[1:]), {"connected": True})
