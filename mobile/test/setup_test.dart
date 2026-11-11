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
      'selects a discovered device without a setup key and connects to an open network',
      (tester) async {
    final client = LiveTestClient();
    await tester.pumpWidget(WifiLinkApp(client: client));
    await tester.pumpAndSettle();
    expect(find.text('wifi status unavailable'), findsOneWidget);
    await tester.tap(find.text('my-pi'));
    await tester.pumpAndSettle();
    expect(find.text('setup key'), findsNothing);
    await tester.tap(find.text('open-wifi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('connect'));
    await tester.pumpAndSettle();
    expect(find.text('connected'), findsOneWidget);
  });

  testWidgets('shows Bluetooth connection errors instead of a scan placeholder',
      (tester) async {
    await tester.pumpWidget(WifiLinkApp(
        client: LiveTestClient(
            openError: const ProvisioningError('device disconnected'))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('my-pi'));
    await tester.pumpAndSettle();
    expect(
        find.text('bluetooth connection: device disconnected'), findsOneWidget);
    expect(find.text('retry'), findsOneWidget);
  });

  testWidgets('shows a Pi scan error separately from connection errors',
      (tester) async {
    await tester.pumpWidget(WifiLinkApp(
        client: LiveTestClient(
            scanError: const ProvisioningError('scan timeout'))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('my-pi'));
    await tester.pumpAndSettle();
    expect(find.text('wifi scan: scan timeout'), findsOneWidget);
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
  LiveTestClient({this.openError, this.scanError});
  final Object? openError;
  final Object? scanError;
  @override
  Stream<PiDevice> discover() => Stream.value(const PiDevice('real', 'my-pi'));
  @override
  Future<void> open(PiDevice device) async {
    if (openError != null) throw openError!;
  }

  @override
  Future<List<WifiNetwork>> networks() async {
    if (scanError != null) throw scanError!;
    return [const WifiNetwork('open-wifi', '00:11:22:33:44:55', 'open', 2412)];
  }

  @override
  Future<void> connect(WifiNetwork network, String password) async {}
  @override
  Future<void> close() async {}
}
