import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpi_wifi_link/provisioning.dart';

class TestGatt implements GattTransport {
  final frames = <List<int>>[];
  final challenge = List<int>.generate(16, (i) => i);
  bool tamper = false;
  @override
  Future<List<int>> read(int characteristic) async {
    if (characteristic == 2) return challenge;
    final response = ProvisioningProtocol.decodeHex(
        '01000102030405060708090a0b3c20b574ab8ba778f924f3a98b9d0a18e6abd52061aa0cc188cf6ed5505830da81a2');
    if (tamper) response[20] ^= 1;
    return response;
  }

  @override
  Future<void> write(List<int> frame) async => frames.add(frame);
}

void main() {
  const key =
      '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f';
  test('matches Python AES-GCM response and frames authenticated requests',
      () async {
    final transport = TestGatt();
    final protocol = ProvisioningProtocol(transport, key);
    expect(await protocol.request({'op': 'scan'}), {'connected': true});
    expect(transport.frames.first.first, 0);
    expect(transport.frames.last.first, 2);
    expect(transport.frames.every((f) => f.length <= 20), isTrue);
    final envelope = transport.frames.expand((f) => f.skip(1)).toList();
    final decoded = await AesGcm.with256bits().decrypt(
      SecretBox(envelope.sublist(12, envelope.length - 16),
          nonce: envelope.sublist(0, 12),
          mac: Mac(envelope.sublist(envelope.length - 16))),
      secretKey: SecretKey(List<int>.generate(32, (i) => i)),
      aad: [
        ...ascii.encode('rpi-wifi-link/v1/request/'),
        ...transport.challenge
      ],
    );
    expect(jsonDecode(utf8.decode(decoded)), {'op': 'scan'});
  });
  test('rejects a modified response', () async {
    final transport = TestGatt()..tamper = true;
    await expectLater(
        ProvisioningProtocol(transport, key).request({'op': 'scan'}),
        throwsA(isA<SecretBoxAuthenticationError>()));
  });
}
