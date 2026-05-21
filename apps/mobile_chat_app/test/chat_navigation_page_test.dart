import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat_app/features/chat/chat_navigation_page.dart';

Widget _buildPage({
  ValueChanged<ChatNavigationAction>? onActionSelected,
  ValueChanged<String>? onChannelRename,
  ValueChanged<String>? onChannelArchive,
  ValueChanged<String>? onChannelSelected,
  VoidCallback? onRequestClose,
  bool closeOnChannelSelected = true,
  List<ChatNodeItem> nodes = const [],
  List<ChatResourceItem> resources = const [],
  TextDirection textDirection = TextDirection.ltr,
}) =>
    MaterialApp(
      home: Directionality(
        textDirection: textDirection,
        child: Scaffold(
          body: ChatNavigationPage(
            onActionSelected: onActionSelected ?? (_) {},
            channels: const [
              ChatChannelItem(id: 'default', name: '默认频道', isDefault: true),
              ChatChannelItem(id: 'project', name: '项目频道'),
            ],
            selectedChannelId: 'default',
            nodes: nodes,
            resources: resources,
            onChannelSelected: onChannelSelected,
            onChannelRename: onChannelRename,
            onChannelArchive: onChannelArchive,
            onRequestClose: onRequestClose,
            closeOnChannelSelected: closeOnChannelSelected,
          ),
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

    testWidgets('three tabs are visible: Channels, Resources, and Nodes',
        (tester) async {
      await tester.pumpWidget(_buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Channels'), findsOneWidget);
      expect(find.text('Resources'), findsOneWidget);
      expect(find.text('Nodes'), findsOneWidget);
    });

    testWidgets('horizontal swipe does not switch tabs', (tester) async {
      var closeCount = 0;

      await tester.pumpWidget(_buildPage(onRequestClose: () => closeCount++));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(ChatNavigationPage),
        const Offset(-200, 0),
      );
      await tester.pumpAndSettle();

      expect(closeCount, 0);
      expect(find.text('New Channel'), findsOneWidget);
      expect(find.text('No nodes'), findsNothing);
    });

    testWidgets('LTR right-to-left swipe requests close', (tester) async {
      var closeCount = 0;

      await tester.pumpWidget(_buildPage(onRequestClose: () => closeCount++));
      await tester.pumpAndSettle();

      await tester.fling(
          find.byType(ChatNavigationPage), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(closeCount, 1);
    });

    testWidgets('RTL left-to-right swipe requests close', (tester) async {
      var closeCount = 0;

      await tester.pumpWidget(
        _buildPage(
          onRequestClose: () => closeCount++,
          textDirection: TextDirection.rtl,
        ),
      );
      await tester.pumpAndSettle();

      await tester.fling(
        find.byType(ChatNavigationPage),
        const Offset(400, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(closeCount, 1);
    });

    testWidgets('Current Chat is not present', (tester) async {
      await tester.pumpWidget(_buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Current Chat'), findsNothing);
    });

    testWidgets('Skills and Agents are not in top-level sidebar',
        (tester) async {
      await tester.pumpWidget(_buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Skills'), findsNothing);
      expect(find.text('Agents'), findsNothing);
      expect(find.text('待实现'), findsNothing);
      expect(find.text('在设置中新建 Agents'), findsNothing);
    });

    testWidgets('Channels tab shows flat channel list with no section header',
        (tester) async {
      await tester.pumpWidget(_buildPage());
      await tester.pumpAndSettle();

      // Channels tab is active by default
      expect(find.text('默认频道'), findsOneWidget);
      expect(find.text('项目频道'), findsOneWidget);
      // No collapsible header for channels
      expect(find.text('频道'), findsNothing);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.text('New Channel'), findsOneWidget);
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
    });

    testWidgets('Channels tab has no expand/collapse toggle', (tester) async {
      await tester.pumpWidget(_buildPage());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_more), findsNothing);
    });

    testWidgets('Nodes tab shows empty state when no nodes', (tester) async {
      await tester.pumpWidget(_buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nodes'));
      await tester.pumpAndSettle();

      expect(find.text('No nodes'), findsOneWidget);
    });

    testWidgets('Nodes tab shows node list when nodes provided',
        (tester) async {
      await tester.pumpWidget(_buildPage(
        nodes: const [
          ChatNodeItem(id: 'node_1', name: 'openclaw 1'),
          ChatNodeItem(id: 'node_2', name: 'openclaw 2'),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nodes'));
      await tester.pumpAndSettle();

      expect(find.text('openclaw 1'), findsOneWidget);
      expect(find.text('openclaw 2'), findsOneWidget);
    });

    testWidgets('tapping node opens Node Detail page', (tester) async {
      await tester.pumpWidget(_buildPage(
        nodes: const [
          ChatNodeItem(id: 'node_1', name: 'openclaw 1'),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nodes'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('openclaw 1'));
      await tester.pumpAndSettle();

      // Node detail page should be open with Skills and Agents sections
      expect(find.text('Skills'), findsOneWidget);
      expect(find.text('Agents'), findsOneWidget);
    });

    testWidgets('Node Detail page shows node agents', (tester) async {
      await tester.pumpWidget(_buildPage(
        nodes: const [
          ChatNodeItem(
            id: 'node_1',
            name: 'openclaw 1',
            agents: [
              ChatAgentItem(name: 'Planner', prompt: ''),
              ChatAgentItem(
                  name: 'Reviewer', prompt: '', description: 'Custom reviewer'),
            ],
          ),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nodes'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('openclaw 1'));
      await tester.pumpAndSettle();

      expect(find.text('Planner'), findsOneWidget);
      expect(find.text('Reviewer'), findsOneWidget);
      expect(find.text('Custom reviewer'), findsOneWidget);
    });

    testWidgets('Resources tab shows empty state when no resources',
        (tester) async {
      await tester.pumpWidget(_buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resources'));
      await tester.pumpAndSettle();

      expect(find.text('No resources'), findsOneWidget);
    });

    testWidgets('Resources tab shows atomic resources by updated time',
        (tester) async {
      await tester.pumpWidget(_buildPage(
        resources: [
          ChatResourceItem(
            id: 'todo_1',
            type: ChatResourceType.todoList,
            title: 'My Todo List',
            updatedAt: DateTime.utc(2026, 5, 19, 8),
            notes: 'Some notes',
          ),
          ChatResourceItem(
            id: 'table_1',
            type: ChatResourceType.assetTable,
            title: 'Asset Table',
            updatedAt: DateTime.utc(2026, 5, 19, 9),
          ),
          ChatResourceItem(
            id: 'highlight_1',
            type: ChatResourceType.textHighlight,
            title: 'Important highlighted text',
            updatedAt: DateTime.utc(2026, 5, 19, 10),
            notes: 'Highlighted text',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resources'));
      await tester.pumpAndSettle();

      expect(find.text('My Todo List'), findsOneWidget);
      expect(find.text('Asset Table'), findsOneWidget);
      expect(find.text('Important highlighted text'), findsOneWidget);
      expect(find.byIcon(Icons.checklist_outlined), findsOneWidget);
      expect(find.byIcon(Icons.table_chart_outlined), findsOneWidget);
      expect(find.byIcon(Icons.format_color_text_outlined), findsOneWidget);

      final highlightTop = tester.getTopLeft(
        find.widgetWithText(ListTile, 'Important highlighted text'),
      );
      final tableTop = tester.getTopLeft(
        find.widgetWithText(ListTile, 'Asset Table'),
      );
      final todoTop = tester.getTopLeft(
        find.widgetWithText(ListTile, 'My Todo List'),
      );
      expect(highlightTop.dy, lessThan(tableTop.dy));
      expect(tableTop.dy, lessThan(todoTop.dy));
    });

    testWidgets('Resources tab can filter by highlight type', (tester) async {
      await tester.pumpWidget(_buildPage(
        resources: [
          ChatResourceItem(
            id: 'todo_1',
            type: ChatResourceType.todoList,
            title: 'My Todo List',
            updatedAt: DateTime.utc(2026, 5, 19, 8),
          ),
          ChatResourceItem(
            id: 'highlight_1',
            type: ChatResourceType.textHighlight,
            title: 'Important highlighted text',
            updatedAt: DateTime.utc(2026, 5, 19, 10),
          ),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resources'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Highlights'));
      await tester.pumpAndSettle();

      expect(find.text('Important highlighted text'), findsOneWidget);
      expect(find.text('My Todo List'), findsNothing);
    });

    testWidgets('tapping resource item opens resource preview page',
        (tester) async {
      await tester.pumpWidget(_buildPage(
        resources: [
          ChatResourceItem(
            id: 'todo_1',
            type: ChatResourceType.todoList,
            title: 'My Todo List',
            updatedAt: DateTime.utc(2026, 5, 19, 8),
            notes: 'A note',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resources'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Todo List'));
      await tester.pumpAndSettle();

      // Preview page opens with the resource title in AppBar and type info
      expect(find.text('Todo List'), findsOneWidget);
      expect(find.text('A note'), findsOneWidget);
    });

    testWidgets('tapping highlight item opens text highlight preview page',
        (tester) async {
      await tester.pumpWidget(_buildPage(
        resources: [
          ChatResourceItem(
            id: 'highlight_1',
            type: ChatResourceType.textHighlight,
            title: 'Important highlighted text',
            updatedAt: DateTime.utc(2026, 5, 19, 10),
            notes: 'Highlighted text',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resources'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Important highlighted text'));
      await tester.pumpAndSettle();

      expect(find.text('Text Highlight'), findsOneWidget);
      expect(find.text('Highlighted text'), findsOneWidget);
    });

    testWidgets('tapping New Channel fires createChannel action',
        (tester) async {
      ChatNavigationAction? received;

      await tester.pumpWidget(_buildPage(
        onActionSelected: (action) => received = action,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Channel'));
      await tester.pumpAndSettle();

      expect(received, ChatNavigationAction.createChannel);
    });

    testWidgets('channel tap requests close by default', (tester) async {
      var closeCount = 0;
      String? selectedChannelId;

      await tester.pumpWidget(
        _buildPage(
          onRequestClose: () => closeCount++,
          onChannelSelected: (id) => selectedChannelId = id,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('项目频道'));
      await tester.pumpAndSettle();

      expect(closeCount, 1);
      expect(selectedChannelId, 'project');
    });

    testWidgets('channel tap can keep inline navigation open', (tester) async {
      var closeCount = 0;
      String? selectedChannelId;

      await tester.pumpWidget(
        _buildPage(
          onRequestClose: () => closeCount++,
          closeOnChannelSelected: false,
          onChannelSelected: (id) => selectedChannelId = id,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('项目频道'));
      await tester.pumpAndSettle();

      expect(closeCount, 0);
      expect(selectedChannelId, 'project');
    });

    testWidgets('back button still requests close when channel tap stays open',
        (tester) async {
      var closeCount = 0;

      await tester.pumpWidget(
        _buildPage(
          onRequestClose: () => closeCount++,
          closeOnChannelSelected: false,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(closeCount, 1);
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
