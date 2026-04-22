import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat_app/features/chat/chat_navigation_page.dart';

Widget _buildPage({
  ValueChanged<ChatNavigationAction>? onActionSelected,
  ValueChanged<String>? onChannelRename,
  ValueChanged<String>? onChannelArchive,
  List<ChatAgentItem> agents = const [],
}) =>
    MaterialApp(
      home: Scaffold(
        body: ChatNavigationPage(
          onActionSelected: onActionSelected ?? (_) {},
          agents: agents,
          channels: const [
            ChatChannelItem(id: 'default', name: '默认频道', isDefault: true),
            ChatChannelItem(id: 'project', name: '项目频道'),
          ],
          selectedChannelId: 'default',
          onChannelRename: onChannelRename,
          onChannelArchive: onChannelArchive,
        ),
      ),
    );

void main() {
  group('ChatNavigationPage – drawer behavior', () {
    testWidgets('tapping Settings icon fires appSettings action',
        (tester) async {
      ChatNavigationAction? received;

      await tester.pumpWidget(_buildPage(
        onActionSelected: (action) => received = action,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      expect(received, ChatNavigationAction.appSettings);
    });

    testWidgets('shows a back button beside Navigation title', (tester) async {
      await tester.pumpWidget(_buildPage());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('Navigation'), findsOneWidget);
    });

    testWidgets('static tiles and channel list are present', (tester) async {
      await tester.pumpWidget(_buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Current Chat'), findsOneWidget);
      expect(find.text('Agents'), findsOneWidget);
      expect(find.text('在设置中新建 Agents'), findsOneWidget);
      expect(find.text('频道'), findsOneWidget);
      expect(find.text('默认频道'), findsOneWidget);
      expect(find.text('项目频道'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.text('新建频道'), findsOneWidget);
      expect(find.text('Manage Agents'), findsNothing);
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
      expect(find.byTooltip('Sessions'), findsNothing);
      expect(find.text('Settings'), findsNothing);
    });

    testWidgets('shows existing agents and source labels', (tester) async {
      await tester.pumpWidget(
        _buildPage(
          agents: const [
            ChatAgentItem(name: 'Planner', isBuiltIn: true),
            ChatAgentItem(name: 'Reviewer', description: 'Custom reviewer'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Planner'), findsOneWidget);
      expect(find.text('Reviewer'), findsOneWidget);
      expect(find.text('内建 Agent'), findsOneWidget);
      expect(find.text('Custom reviewer'), findsOneWidget);
      expect(find.text('在设置中新建 Agents'), findsNothing);
    });

    testWidgets('tapping Agents title toggles section collapse',
        (tester) async {
      await tester.pumpWidget(_buildPage());
      await tester.pumpAndSettle();

      // Starts expanded: expand_more icon visible, content visible
      expect(find.byIcon(Icons.expand_more), findsWidgets);
      expect(find.text('在设置中新建 Agents'), findsOneWidget);

      await tester.tap(find.text('Agents'));
      await tester.pumpAndSettle();
      // After collapse: chevron_right icon for Agents, content hidden
      expect(find.text('在设置中新建 Agents'), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await tester.tap(find.text('Agents'));
      await tester.pumpAndSettle();
      expect(find.text('在设置中新建 Agents'), findsOneWidget);
    });

    testWidgets('tapping 频道 title toggles section collapse', (tester) async {
      await tester.pumpWidget(_buildPage());
      await tester.pumpAndSettle();

      expect(find.text('默认频道'), findsOneWidget);
      expect(find.text('项目频道'), findsOneWidget);
      await tester.tap(find.text('频道'));
      await tester.pumpAndSettle();
      expect(find.text('默认频道'), findsNothing);
      expect(find.text('项目频道'), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('tapping 配置 fires manageAgents action', (tester) async {
      ChatNavigationAction? received;
      await tester.pumpWidget(
        _buildPage(onActionSelected: (action) => received = action),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('配置'));
      await tester.pumpAndSettle();

      expect(received, ChatNavigationAction.manageAgents);
    });

    testWidgets('tapping 新建频道 fires createChannel action', (tester) async {
      ChatNavigationAction? received;

      await tester.pumpWidget(_buildPage(
        onActionSelected: (action) => received = action,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('新建频道'));
      await tester.pumpAndSettle();

      expect(received, ChatNavigationAction.createChannel);
    });

    testWidgets('long press channel can trigger rename', (tester) async {
      String? renamedId;
      await tester
          .pumpWidget(_buildPage(onChannelRename: (id) => renamedId = id));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('项目频道'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('改名'));
      await tester.pumpAndSettle();

      expect(renamedId, 'project');
    });

    testWidgets('long press channel can trigger archive', (tester) async {
      String? archivedId;
      await tester
          .pumpWidget(_buildPage(onChannelArchive: (id) => archivedId = id));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('项目频道'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('归档'));
      await tester.pumpAndSettle();

      expect(archivedId, 'project');
    });

    testWidgets('tapping back button closes an open drawer', (tester) async {
      final scaffoldKey = GlobalKey<ScaffoldState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            key: scaffoldKey,
            drawer: Drawer(
              child: ChatNavigationPage(
                onActionSelected: (_) {},
                agents: const [],
                channels: const [
                  ChatChannelItem(
                    id: 'default',
                    name: '默认频道',
                    isDefault: true,
                  ),
                ],
                selectedChannelId: 'default',
              ),
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
