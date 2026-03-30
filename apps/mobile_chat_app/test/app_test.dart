import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat_app/app/app.dart';

void main() {
  testWidgets('BricksApp renders ChatScreen with composer', (tester) async {
    await tester.pumpWidget(const BricksApp());

    // Check that session name is displayed in the AppBar
    expect(find.text('| New Session'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Sending an empty message does nothing', (tester) async {
    await tester.pumpWidget(const BricksApp());

    // Tap send without entering text
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    // No messages should appear
    expect(find.text('Start a conversation to create something.'), findsOneWidget);
  });
}
