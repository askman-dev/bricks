import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat_app/features/chat/widgets/composer_bar.dart';

// The ComposerBar's spin animation runs indefinitely. Use pump() + a fixed
// duration instead of pumpAndSettle() to avoid timeouts.
const _settle = Duration(milliseconds: 300);

Widget _buildBar(
        {VoidCallback? onOpenModelSelection,
        VoidCallback? onShowInfo,
        Widget? routerAction,
        bool showRouteAtMarker = false}) =>
    MaterialApp(
      home: Scaffold(
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ComposerBar(
              routerAction: routerAction,
              showRouteAtMarker: showRouteAtMarker,
              onOpenModelSelection: onOpenModelSelection,
              onShowInfo: onShowInfo,
            ),
          ],
        ),
      ),
    );

void main() {
  group('ComposerBar – popup menu', () {
    testWidgets('selecting model action triggers onOpenModelSelection',
        (tester) async {
      var called = false;

      await tester.pumpWidget(_buildBar(onOpenModelSelection: () {
        called = true;
      }));
      await tester.pump();

      // Retrieve the PopupMenuButton and invoke its onSelected handler directly
      // to avoid popup-positioning issues in the headless test environment.
      final button = tester.widget<PopupMenuButton<ComposerMenuAction>>(
        find.byType(PopupMenuButton<ComposerMenuAction>),
      );
      button.onSelected?.call(ComposerMenuAction.model);
      await tester.pump();

      expect(called, isTrue);
    });

    testWidgets('selecting newContext action does not throw', (tester) async {
      await tester.pumpWidget(_buildBar());
      await tester.pump();

      final button = tester.widget<PopupMenuButton<ComposerMenuAction>>(
        find.byType(PopupMenuButton<ComposerMenuAction>),
      );
      // No exception — action is a no-op for now.
      button.onSelected?.call(ComposerMenuAction.newContext);
      await tester.pump();
    });

    testWidgets('selecting agents action does not throw', (tester) async {
      await tester.pumpWidget(_buildBar());
      await tester.pump();

      final button = tester.widget<PopupMenuButton<ComposerMenuAction>>(
        find.byType(PopupMenuButton<ComposerMenuAction>),
      );
      // No exception — action is a no-op for now.
      button.onSelected?.call(ComposerMenuAction.agents);
      await tester.pump();
    });

    testWidgets('selecting info action triggers onShowInfo', (tester) async {
      var called = false;

      await tester.pumpWidget(_buildBar(onShowInfo: () => called = true));
      await tester.pump();

      final button = tester.widget<PopupMenuButton<ComposerMenuAction>>(
        find.byType(PopupMenuButton<ComposerMenuAction>),
      );
      button.onSelected?.call(ComposerMenuAction.info);
      await tester.pump();

      expect(called, isTrue);
    });

    testWidgets('popup menu items are present in the menu builder',
        (tester) async {
      await tester.pumpWidget(_buildBar());
      await tester.pump();

      final button = tester.widget<PopupMenuButton<ComposerMenuAction>>(
        find.byType(PopupMenuButton<ComposerMenuAction>),
      );
      final items = button.itemBuilder(tester.element(
        find.byType(PopupMenuButton<ComposerMenuAction>),
      ));

      final values = items
          .whereType<PopupMenuItem<ComposerMenuAction>>()
          .map((i) => i.value)
          .toList();
      expect(
          values,
          containsAll([
            ComposerMenuAction.newContext,
            ComposerMenuAction.model,
            ComposerMenuAction.agents,
            ComposerMenuAction.info,
          ]));
    });

    testWidgets('popup menu is disabled while streaming', (tester) async {
      var called = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ComposerBar(
                  isStreaming: true,
                  onOpenModelSelection: () => called = true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // The PopupMenuButton should be disabled; onSelected should not be called.
      final button = tester.widget<PopupMenuButton<ComposerMenuAction>>(
        find.byType(PopupMenuButton<ComposerMenuAction>),
      );
      expect(button.enabled, isFalse);
      expect(called, isFalse);
    });

    testWidgets('renders optional router action before composer menu button',
        (tester) async {
      await tester.pumpWidget(
        _buildBar(
          routerAction: const IconButton(
            onPressed: null,
            tooltip: 'Router settings',
            icon: Icon(Icons.alt_route),
          ),
        ),
      );
      await tester.pump();

      final routerActionFinder = find.byTooltip('Router settings');
      final menuButtonFinder = find.byType(PopupMenuButton<ComposerMenuAction>);

      expect(routerActionFinder, findsOneWidget);
      expect(menuButtonFinder, findsOneWidget);

      final routerActionPosition = tester.getTopLeft(routerActionFinder);
      final menuButtonPosition = tester.getTopLeft(menuButtonFinder);

      expect(routerActionPosition.dx, lessThan(menuButtonPosition.dx));
    });
  });

  group('ComposerBar – send / stop controls', () {
    testWidgets('send button is present when not streaming', (tester) async {
      await tester.pumpWidget(_buildBar());
      await tester.pump();

      expect(find.byTooltip('Send'), findsOneWidget);
      expect(find.byTooltip('Stop'), findsNothing);
    });

    testWidgets('stop button is shown while streaming', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComposerBar(
              isStreaming: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byTooltip('Stop'), findsOneWidget);
      expect(find.byTooltip('Send'), findsNothing);
    });

    testWidgets('send callback fires with trimmed text', (tester) async {
      String? sent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComposerBar(
              onSend: (text) => sent = text,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), '  hello  ');
      await tester.tap(find.byTooltip('Send'));
      await tester.pump(_settle);

      expect(sent, 'hello');
    });
  });

  group('ComposerBar – route marker', () {
    testWidgets('shows @ marker when enabled', (tester) async {
      await tester.pumpWidget(
        _buildBar(
          showRouteAtMarker: true,
          routerAction: const IconButton(
            onPressed: null,
            tooltip: 'Router settings',
            icon: Icon(Icons.alt_route),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('@'), findsOneWidget);
    });

    testWidgets('hides @ marker when disabled', (tester) async {
      await tester.pumpWidget(_buildBar(showRouteAtMarker: false));
      await tester.pump();

      expect(find.text('@'), findsNothing);
    });
  });
}
