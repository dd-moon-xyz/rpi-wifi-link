import 'provisioning.dart';

class DemoProvisioningClient implements ProvisioningClient {
  String _device = '';
  @override
  Stream<PiDevice> discover() => Stream.fromIterable(
      const [PiDevice('1', 'raspi-01'), PiDevice('2', 'raspi-02')]);
  @override
  Future<void> open(PiDevice device, String key) async {
    _device = device.id;
  }

  @override
  Future<List<WifiNetwork>> networks() async => [
        for (var i = 1; i <= 3; i++) WifiNetwork('wifi-0$i', '$i', 'wpa2', 2412)
      ];
  @override
  Future<void> connect(WifiNetwork network, String password) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (_device == '2')
      throw const ProvisioningError('check your password and try again.');
  }

  @override
  Future<void> close() async {}
}
