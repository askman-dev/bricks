import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat_app/features/settings/node_settings_screen.dart';
import 'package:mobile_chat_app/features/settings/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'settings screen shows Node Management and does not show Openclaw Token',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Node Management'), findsOneWidget);
    expect(find.text('Openclaw Token'), findsNothing);
  });

  testWidgets('tapping Node Management navigates to NodeSettingsScreen',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Node Management'));
    // Pump a few frames to allow the navigation push to occur without
    // waiting for the async network calls inside NodeSettingsScreen to
    // settle (they would time out in a unit-test environment).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(NodeSettingsScreen), findsOneWidget);
  });
}
