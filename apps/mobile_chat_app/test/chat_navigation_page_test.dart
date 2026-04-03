import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat_app/features/chat/chat_navigation_page.dart';

Widget _buildPage({ValueChanged<ChatNavigationAction>? onActionSelected}) =>
    MaterialApp(
      home: Scaffold(
        body: ChatNavigationPage(
          onActionSelected: onActionSelected ?? (_) {},
        ),
      ),
    );

void main() {
  group('ChatNavigationPage – drawer behavior', () {
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

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('Navigation'), findsOneWidget);
    });

    testWidgets('static tiles (Current Chat, Sessions) are present',
        (tester) async {
      await tester.pumpWidget(_buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Current Chat'), findsOneWidget);
      expect(find.text('Sessions'), findsOneWidget);
    });

    testWidgets('tapping back button closes an open drawer', (tester) async {
      final scaffoldKey = GlobalKey<ScaffoldState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            key: scaffoldKey,
            drawer: Drawer(
              child: ChatNavigationPage(onActionSelected: (_) {}),
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      scaffoldKey.currentState!.openDrawer();
      await tester.pumpAndSettle();
      expect(scaffoldKey.currentState!.isDrawerOpen, isTrue);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(scaffoldKey.currentState!.isDrawerOpen, isFalse);
    });
  });
}
