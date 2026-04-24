import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat_app/features/chat/widgets/composer_bar.dart';

// The ComposerBar's spin animation runs indefinitely. Use pump() + a fixed
// duration instead of pumpAndSettle() to avoid timeouts.
const _settle = Duration(milliseconds: 300);

Widget _buildBar(
        {VoidCallback? onOpenModelSelection,
        VoidCallback? onShowInfo,
        List<Widget> leadingActions = const [],
        bool showComposerConfigMenu = true,
        String? activeModelLabel,
        List<String> slashCommands = const [],
        List<ComposerAtAction> atActions = const [],
        void Function(String value)? onAtActionSelected}) =>
    MaterialApp(
      home: Scaffold(
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ComposerBar(
              agents: const [],
              leadingActions: leadingActions,
              showComposerConfigMenu: showComposerConfigMenu,
              activeModelLabel: activeModelLabel,
              slashCommands: slashCommands,
              atActions: atActions,
              onAtActionSelected: onAtActionSelected,
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
            ComposerMenuAction.model,
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
                  agents: const [],
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

    testWidgets('renders optional leading action before composer menu button',
        (tester) async {
      await tester.pumpWidget(
        _buildBar(
          leadingActions: const [
            IconButton(
              onPressed: null,
              tooltip: 'Router settings',
              icon: Icon(Icons.alt_route),
            ),
          ],
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

    testWidgets('hides composer menu when disabled', (tester) async {
      await tester.pumpWidget(_buildBar(showComposerConfigMenu: false));
      await tester.pump();

      expect(find.byType(PopupMenuButton<ComposerMenuAction>), findsNothing);
    });

    testWidgets('shows active model label under model item', (tester) async {
      await tester.pumpWidget(_buildBar(activeModelLabel: 'claude-sonnet-4-5'));
      await tester.pump();

      final button = tester.widget<PopupMenuButton<ComposerMenuAction>>(
        find.byType(PopupMenuButton<ComposerMenuAction>),
      );
      final items = button.itemBuilder(
        tester.element(find.byType(PopupMenuButton<ComposerMenuAction>)),
      );
      final modelItem = items
          .whereType<PopupMenuItem<ComposerMenuAction>>()
          .firstWhere((item) => item.value == ComposerMenuAction.model);
      final content = modelItem.child! as Column;
      expect((content.children[0] as Text).data, '模型');
      expect((content.children[1] as Text).data, 'claude-sonnet-4-5');
    });

    testWidgets('selecting slash command fills input', (tester) async {
      await tester.pumpWidget(_buildBar(slashCommands: const ['/status']));
      await tester.pump();

      final button = tester.widget<PopupMenuButton<String>>(
        find.byType(PopupMenuButton<String>),
      );
      button.onSelected?.call('/status');
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, '/status ');
    });

    testWidgets('selecting @ action triggers callback', (tester) async {
      String? selected;
      await tester.pumpWidget(
        _buildBar(
          atActions: const [
            ComposerAtAction(value: 'Planner', label: 'Planner'),
          ],
          onAtActionSelected: (value) => selected = value,
        ),
      );
      await tester.pump();

      final button = tester.widget<PopupMenuButton<String>>(
        find.byType(PopupMenuButton<String>),
      );
      button.onSelected?.call('Planner');
      await tester.pump();

      expect(selected, 'Planner');
    });

    testWidgets('selecting @ action inserts configured mention text',
        (tester) async {
      await tester.pumpWidget(
        _buildBar(
          atActions: const [
            ComposerAtAction(
              value: 'openclaw:node:main',
              label: 'Main Agent',
              insertText: '@main ',
            ),
          ],
        ),
      );
      await tester.pump();

      final button = tester.widget<PopupMenuButton<String>>(
        find.byType(PopupMenuButton<String>),
      );
      button.onSelected?.call('openclaw:node:main');
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, '@main ');
    });

    testWidgets('@ menu supports disabled placeholder item', (tester) async {
      await tester.pumpWidget(
        _buildBar(
          atActions: const [
            ComposerAtAction(
              value: '__todo__',
              label: '待实现',
              enabled: false,
            ),
          ],
        ),
      );
      await tester.pump();

      final button = tester.widget<PopupMenuButton<String>>(
        find.byType(PopupMenuButton<String>),
      );
      final items = button.itemBuilder(
        tester.element(find.byType(PopupMenuButton<String>)),
      );
      final placeholder = items.whereType<PopupMenuItem<String>>().single;
      expect(placeholder.enabled, isFalse);
      expect((placeholder.child as Text).data, '待实现');
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

  group('ComposerBar – input copy', () {
    testWidgets('input area does not show @ prefix/hint', (tester) async {
      await tester.pumpWidget(_buildBar());
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.hintText, 'Ask Bricks to create something…');
      expect(textField.decoration?.prefixIcon, isNull);
    });
  });
}
