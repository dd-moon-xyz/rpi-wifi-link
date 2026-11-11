import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpi_wifi_link/main.dart';

void main() {
  Future<void> chooseNetwork(WidgetTester tester,
      {bool failure = false}) async {
    await tester.pumpWidget(const WifiLinkApp());
    await tester.tap(find.text(failure ? 'raspi-02' : 'raspi-01'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('wifi-01'));
    await tester.pumpAndSettle();
  }

  testWidgets('validates the password and completes a simulated connection',
      (tester) async {
    await chooseNetwork(tester);
    await tester.tap(find.text('connect'));
    await tester.pump();
    expect(find.text('enter at least 8 characters.'), findsOneWidget);
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
