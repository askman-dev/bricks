import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat_app/features/chat/chat_navigation_page.dart';

Widget _buildPage({ValueChanged<ChatNavigationAction>? onActionSelected}) =>
    MaterialApp(
      home: Scaffold(
        body: ChatNavigationPage(onActionSelected: onActionSelected),
      ),
    );

void main() {
  group('ChatNavigationPage – action callbacks', () {
    testWidgets('tapping Manage Agents fires manageAgents action',
        (tester) async {
      ChatNavigationAction? received;

      await tester.pumpWidget(_buildPage(
        onActionSelected: (action) => received = action,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manage Agents'));
      await tester.pumpAndSettle();

      expect(received, ChatNavigationAction.manageAgents);
    });

    testWidgets('tapping Settings fires appSettings action', (tester) async {
      ChatNavigationAction? received;

      await tester.pumpWidget(_buildPage(
        onActionSelected: (action) => received = action,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(received, ChatNavigationAction.appSettings);
    });

    testWidgets('static tiles (Current Chat, Sessions) are present',
        (tester) async {
      await tester.pumpWidget(_buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Current Chat'), findsOneWidget);
      expect(find.text('Sessions'), findsOneWidget);
    });

    testWidgets(
        'without callback, tapping action calls Navigator.pop with action',
        (tester) async {
      ChatNavigationAction? popped;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                popped = await Navigator.push<ChatNavigationAction>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const Scaffold(
                      body: ChatNavigationPage(),
                    ),
                  ),
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to the page.
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      // Tap 'Manage Agents' — should pop with manageAgents.
      await tester.tap(find.text('Manage Agents'));
      await tester.pumpAndSettle();

      expect(popped, ChatNavigationAction.manageAgents);
    });
  });
}
