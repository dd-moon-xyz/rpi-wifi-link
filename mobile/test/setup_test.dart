import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpi_wifi_link/main.dart';
import 'package:rpi_wifi_link/demo_provisioning.dart';
import 'package:rpi_wifi_link/provisioning.dart';

void main() {
  Future<void> chooseNetwork(WidgetTester tester,
      {bool failure = false}) async {
    await tester.pumpWidget(WifiLinkApp(client: DemoProvisioningClient()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(failure ? 'raspi-02' : 'raspi-01'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    await tester.tap(find.text('wifi-01'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'authenticates a discovered device and connects to an open network',
      (tester) async {
    final client = LiveTestClient();
    await tester.pumpWidget(WifiLinkApp(client: client));
    await tester.pumpAndSettle();
    expect(find.text('wifi status unavailable'), findsOneWidget);
    await tester.tap(find.text('my-pi'));
    await tester.pumpAndSettle();
    expect(find.text('setup key'), findsOneWidget);
    final key = List.filled(64, 'a').join();
    await tester.enterText(find.byType(TextField), key);
    await tester.tap(find.text('continue'));
    await tester.pumpAndSettle();
    expect(client.receivedKey, key);
    await tester.tap(find.text('open-wifi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('connect'));
    await tester.pumpAndSettle();
    expect(find.text('connected'), findsOneWidget);
  });

  testWidgets('validates the password and completes a simulated connection',
      (tester) async {
    await chooseNetwork(tester);
    await tester.tap(find.text('connect'));
    await tester.pump();
    expect(find.text('enter 8–63 ASCII characters or a 64-digit hex key.'),
        findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'demo-password');
    await tester.tap(find.text('connect'));
    await tester.pump();
    expect(find.text('connecting...'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('connected'), findsOneWidget);
    await tester.tap(find.text('< back to devices'));
    await tester.pumpAndSettle();
    expect(find.text('devices'), findsOneWidget);
  });

  testWidgets('allows retry after a simulated failure', (tester) async {
    await chooseNetwork(tester, failure: true);
    await tester.enterText(find.byType(TextFormField), 'demo-password');
    await tester.tap(find.text('connect'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('connection failed'), findsOneWidget);
    await tester.tap(find.text('retry'));
    await tester.pumpAndSettle();
    expect(find.text('connect device'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        isEmpty);
    await tester.enterText(find.byType(TextFormField), 'another-password');
    await tester.tap(find.text('connect'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('connection failed'), findsOneWidget);
    await tester.tap(find.text('< back to devices'));
    await tester.pumpAndSettle();
    expect(find.text('disconnected'), findsNWidgets(2));
  });
}

class LiveTestClient implements ProvisioningClient {
  String? receivedKey;
  @override
  Stream<PiDevice> discover() => Stream.value(const PiDevice('real', 'my-pi'));
  @override
  Future<void> open(PiDevice device, String key) async {
    receivedKey = key;
  }

  @override
  Future<List<WifiNetwork>> networks() async =>
      [const WifiNetwork('open-wifi', '00:11:22:33:44:55', 'open', 2412)];
  @override
  Future<void> connect(WifiNetwork network, String password) async {}
  @override
  Future<void> close() async {}
}
