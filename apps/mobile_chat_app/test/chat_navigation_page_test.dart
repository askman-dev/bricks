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

    testWidgets('shows a back button beside Navigation title', (tester) async {
      await tester.pumpWidget(_buildPage());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
      expect(find.text('Navigation'), findsOneWidget);
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

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manage Agents'));
      await tester.pumpAndSettle();

      expect(popped, ChatNavigationAction.manageAgents);
    });

    testWidgets('tapping back button pops the route', (tester) async {
      bool didReturn = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const Scaffold(
                      body: ChatNavigationPage(),
                    ),
                  ),
                );
                didReturn = true;
              },
              child: const Text('go-back'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('go-back'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();

      expect(didReturn, isTrue);
    });
  });
}
