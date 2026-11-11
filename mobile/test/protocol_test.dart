import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpi_wifi_link/provisioning.dart';

class TestGatt implements GattTransport {
  final frames = <List<int>>[];
  List<int> response = [1, ...utf8.encode('{"connected":true}')];
  @override
  Future<List<int>> read(int characteristic) async {
    expect(characteristic, 4);
    return response;
  }

  @override
  Future<void> write(List<int> frame) async => frames.add(frame);
}

void main() {
  test('frames a short scan request without a setup key or challenge',
      () async {
    final transport = TestGatt();
    expect(await ProvisioningProtocol(transport).request({'op': 'scan'}),
        {'connected': true});
    expect(transport.frames.first.first, 0);
    expect(transport.frames.last.first, 2);
    expect(
        transport.frames.every((f) => f.length >= 2 && f.length <= 20), isTrue);
    expect(
        jsonDecode(
            utf8.decode(transport.frames.expand((f) => f.skip(1)).toList())),
        {'op': 'scan'});
  });
  test('frames multi-packet requests and preserves the complete JSON payload',
      () async {
    final transport = TestGatt();
    final request = {
      'op': 'connect',
      'bssid': '00:11:22:33:44:55',
      'password': 'a-test-password'
    };
    await ProvisioningProtocol(transport).request(request);
    expect(transport.frames.length, greaterThan(2));
    expect(
        transport.frames
            .skip(1)
            .take(transport.frames.length - 2)
            .every((f) => f.first == 1),
        isTrue);
    expect(
        jsonDecode(
            utf8.decode(transport.frames.expand((f) => f.skip(1)).toList())),
        request);
  });
  test('rejects an invalid response marker', () async {
    final transport = TestGatt()..response = [9];
    await expectLater(ProvisioningProtocol(transport).request({'op': 'scan'}),
        throwsA(isA<ProvisioningError>()));
  });
  test('reports a Pi scan error', () async {
    final transport = TestGatt()
      ..response = [1, ...utf8.encode('{"error":"scan_timeout"}')];
    await expectLater(
        ProvisioningProtocol(transport).request({'op': 'scan'}),
        throwsA(isA<ProvisioningError>()
            .having((e) => e.message, 'message', 'scan timeout')));
  });
}
