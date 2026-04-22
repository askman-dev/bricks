import 'package:chat_domain/chat_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat_app/features/chat/widgets/composer_bar.dart';

// The ComposerBar's spin animation runs indefinitely. Use pump() + a fixed
// duration instead of pumpAndSettle() to avoid timeouts.
const _settle = Duration(milliseconds: 300);

Widget _buildBar({Widget? routerAction}) => MaterialApp(
      home: Scaffold(
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ComposerBar(
              agents: const [],
              routerAction: routerAction,
            ),
          ],
        ),
      ),
    );

void main() {
  group('ComposerBar – popup menu', () {
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
            ComposerMenuAction.agents,
          ]));
    });

    testWidgets('popup menu is disabled while streaming', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ComposerBar(
                  agents: const [],
                  isStreaming: true,
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
              agents: const [],
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
              agents: const [],
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

  group('ComposerBar – @mention suggestions', () {
    final agents = [
      AgentDefinition(
        name: 'my-agent',
        description: 'A test agent',
        model: 'sonnet',
        systemPrompt: 'You are helpful.',
      ),
    ];

    testWidgets('typing @ shows agent suggestion', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComposerBar(
              agents: agents,
              // onSend must be non-null to enable the TextField.
              onSend: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Focus the TextField then type the trigger character.
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '@');
      await tester.pump();

      expect(find.text('@my-agent'), findsOneWidget);
    });
  });
}
