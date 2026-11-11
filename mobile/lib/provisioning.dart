import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class PiDevice {
  const PiDevice(this.id, this.name);
  final String id;
  final String name;
}

class WifiNetwork {
  const WifiNetwork(this.name, this.bssid, this.security, this.mhz);
  final String name;
  final String bssid;
  final String security;
  final int mhz;
}

class ProvisioningError implements Exception {
  const ProvisioningError(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class ProvisioningClient {
  Stream<PiDevice> discover();
  Future<void> open(PiDevice device, String key);
  Future<List<WifiNetwork>> networks();
  Future<void> connect(WifiNetwork network, String password);
  Future<void> close();
}

abstract class GattTransport {
  Future<List<int>> read(int characteristic);
  Future<void> write(List<int> frame);
}

class ProvisioningProtocol {
  ProvisioningProtocol(this.transport, String key)
      : key = SecretKey(decodeHex(key));
  final GattTransport transport;
  final SecretKey key;
  final _cipher = AesGcm.with256bits();

  static List<int> decodeHex(String value) {
    if (!RegExp(r'^(?:[0-9a-fA-F]{2})+$').hasMatch(value)) {
      throw const ProvisioningError('invalid hexadecimal value');
    }
    return [
      for (var i = 0; i < value.length; i += 2)
        int.parse(value.substring(i, i + 2), radix: 16)
    ];
  }

  Future<Map<String, dynamic>> request(Map<String, dynamic> request) async {
    final challenge = await transport.read(2);
    if (challenge.length != 16)
      throw const ProvisioningError('invalid device challenge');
    final box = await _cipher.encrypt(utf8.encode(jsonEncode(request)),
        secretKey: key,
        aad: [...ascii.encode('rpi-wifi-link/v1/request/'), ...challenge]);
    final envelope = [...box.nonce, ...box.cipherText, ...box.mac.bytes];
    if (envelope.length > 384)
      throw const ProvisioningError('request too large');
    for (var offset = 0; offset < envelope.length; offset += 19) {
      final end = (offset + 19).clamp(0, envelope.length);
      await transport.write([
        offset == 0
            ? 0
            : end == envelope.length
                ? 2
                : 1,
        ...envelope.sublist(offset, end)
      ]);
    }
    final deadline = DateTime.now().add(const Duration(seconds: 100));
    while (DateTime.now().isBefore(deadline)) {
      final value = await transport.read(4);
      if (value.length == 1 && value[0] == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        continue;
      }
      if (value.length < 29 || value[0] != 1)
        throw const ProvisioningError('invalid device response');
      final plaintext = await _cipher.decrypt(
          SecretBox(value.sublist(13, value.length - 16),
              nonce: value.sublist(1, 13),
              mac: Mac(value.sublist(value.length - 16))),
          secretKey: key,
          aad: [...ascii.encode('rpi-wifi-link/v1/response/'), ...challenge]);
      final result = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
      if (result['error'] != null)
        throw ProvisioningError(
            result['error'].toString().replaceAll('_', ' '));
      return result;
    }
    throw const ProvisioningError('device response timed out');
  }
}

class BleProvisioningClient implements ProvisioningClient, GattTransport {
  final _ble = FlutterReactiveBle();
  static final service = Uuid.parse('a0df0001-3d38-45b9-908f-a9ae97048720');
  StreamSubscription<ConnectionStateUpdate>? _connection;
  String? _id;
  ProvisioningProtocol? _protocol;
  bool _connected = false;

  @override
  Stream<PiDevice> discover() async* {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final granted = await const MethodChannel('rpi-wifi-link/permissions')
          .invokeMethod<bool>('bluetooth');
      if (granted != true)
        throw const ProvisioningError('bluetooth permission required');
    }
    await _ble.statusStream
        .firstWhere((s) => s != BleStatus.unknown)
        .timeout(const Duration(seconds: 10));
    if (_ble.status != BleStatus.ready)
      throw const ProvisioningError(
          'enable bluetooth and required permissions');
    yield* _ble.scanForDevices(withServices: [
      service
    ], scanMode: ScanMode.lowLatency).map(
        (d) => PiDevice(d.id, d.name.isEmpty ? 'raspi' : d.name));
  }

  @override
  Future<void> open(PiDevice device, String key) async {
    await close();
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(key))
      throw const ProvisioningError('enter a 64-character setup key');
    _id = device.id;
    final ready = Completer<void>();
    _connection = _ble
        .connectToDevice(
            id: device.id, connectionTimeout: const Duration(seconds: 15))
        .listen((update) {
      _connected = update.connectionState == DeviceConnectionState.connected;
      if (_connected && !ready.isCompleted) ready.complete();
      if (update.connectionState == DeviceConnectionState.disconnected &&
          !ready.isCompleted) {
        ready.completeError(const ProvisioningError('device disconnected'));
      }
    }, onError: (Object error) {
      _connected = false;
      if (!ready.isCompleted) ready.completeError(error);
    });
    try {
      await ready.future.timeout(const Duration(seconds: 20));
      _protocol = ProvisioningProtocol(this, key);
    } catch (_) {
      await close();
      rethrow;
    }
  }

  QualifiedCharacteristic _characteristic(int n) {
    if (!_connected || _id == null)
      throw const ProvisioningError('device disconnected');
    return QualifiedCharacteristic(
        deviceId: _id!,
        serviceId: service,
        characteristicId: Uuid.parse('a0df000$n-3d38-45b9-908f-a9ae97048720'));
  }

  @override
  Future<List<int>> read(int characteristic) => _ble
      .readCharacteristic(_characteristic(characteristic))
      .timeout(const Duration(seconds: 10));
  @override
  Future<void> write(List<int> frame) => _ble
      .writeCharacteristicWithResponse(_characteristic(3), value: frame)
      .timeout(const Duration(seconds: 10));

  @override
  Future<List<WifiNetwork>> networks() async {
    final protocol = _protocol;
    if (protocol == null)
      throw const ProvisioningError('connect to a device first');
    final networks = <WifiNetwork>[];
    var page = await protocol.request({'op': 'scan'});
    for (var index = 1; index <= 256; index++) {
      networks.addAll((page['networks'] as List).map((n) => WifiNetwork(
          utf8.decode(ProvisioningProtocol.decodeHex(n['ssid'] as String),
              allowMalformed: true),
          n['bssid'] as String,
          n['security'] as String,
          n['mhz'] as int)));
      if (page['more'] != true) return networks;
      if (index == 256) throw const ProvisioningError('too many network pages');
      page = await protocol.request({'op': 'page', 'index': index});
    }
    return networks;
  }

  @override
  Future<void> connect(WifiNetwork network, String password) async {
    if (_protocol == null)
      throw const ProvisioningError('connect to a device first');
    final result = await _protocol!.request(
        {'op': 'connect', 'bssid': network.bssid, 'password': password});
    if (result['connected'] != true)
      throw const ProvisioningError('connection failed');
  }

  @override
  Future<void> close() async {
    _connected = false;
    _protocol = null;
    _id = null;
    await _connection?.cancel();
    _connection = null;
  }
}
