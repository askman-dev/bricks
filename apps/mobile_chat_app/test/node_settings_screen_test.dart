import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat_app/features/settings/llm_config_service.dart';
import 'package:mobile_chat_app/features/settings/node_settings_screen.dart';

class _FakeNodeService extends LlmConfigService {
  _FakeNodeService({this.empty = false});

  final bool empty;
  final List<PlatformNodeConfig> nodes = [];

  @override
  Future<List<PlatformNodeConfig>> fetchPlatformNodes() async {
    if (empty && nodes.isEmpty) return const [];
    if (nodes.isEmpty) {
      nodes.add(
        const PlatformNodeConfig(
          nodeId: 'node_1',
          displayName: 'openclaw 1',
          pluginId: 'plugin_node_1',
        ),
      );
    }
    return List<PlatformNodeConfig>.from(nodes);
  }

  @override
  Future<PlatformNodeConfig> createPlatformNode({String? displayName}) async {
    final created = PlatformNodeConfig(
      nodeId: 'node_${nodes.length + 1}',
      displayName: displayName ?? 'openclaw ${nodes.length + 1}',
      pluginId: 'plugin_node_${nodes.length + 1}',
    );
    nodes.add(created);
    return created;
  }

  @override
  Future<PlatformNodeConfig> renamePlatformNode({
    required String nodeId,
    required String displayName,
  }) async {
    final index = nodes.indexWhere((item) => item.nodeId == nodeId);
    if (index >= 0) {
      final updated = PlatformNodeConfig(
        nodeId: nodeId,
        displayName: displayName,
        pluginId: nodes[index].pluginId,
      );
      nodes[index] = updated;
      return updated;
    }
    return PlatformNodeConfig(
        nodeId: nodeId, displayName: displayName, pluginId: 'plugin_unknown');
  }

  @override
  Future<PlatformTokenBundle> fetchPlatformToken(
      {String? nodeId, String pluginId = 'plugin_local_main'}) async {
    return const PlatformTokenBundle(
      nodeId: 'node_1',
      nodeName: 'openclaw 1',
      token: 'token-123',
      pluginId: 'plugin_node_1',
      baseUrl: 'https://example.com',
      scopes: ['events:read'],
      expiresIn: '30d',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows empty-state create button when no nodes', (tester) async {
    final service = _FakeNodeService(empty: true);
    await tester
        .pumpWidget(MaterialApp(home: NodeSettingsScreen(service: service)));
    await tester.pumpAndSettle();

    expect(find.text('创建第一个节点'), findsOneWidget);
  });

  testWidgets('renders node and can copy OpenClaw config commands',
      (tester) async {
    final clipboardCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardCalls.add(call);
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final service = _FakeNodeService();
    await tester
        .pumpWidget(MaterialApp(home: NodeSettingsScreen(service: service)));
    await tester.pumpAndSettle();

    expect(find.text('openclaw 1'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, '生成 Token'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'openclaw config set channels.dev-askman-bricks.BRICKS_BASE_URL',
      ),
      findsOneWidget,
    );
    expect(find.textContaining("'https://example.com'"), findsOneWidget);
    expect(find.textContaining("'plugin_node_1'"), findsOneWidget);
    expect(find.textContaining("'token-123'"), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '复制 OpenClaw 命令'));
    await tester.pumpAndSettle();

    expect(clipboardCalls, hasLength(1));
    final copiedCommands = clipboardCalls.single.arguments['text'] as String;
    expect(
      copiedCommands,
      contains(
        "openclaw config set channels.dev-askman-bricks.BRICKS_BASE_URL 'https://example.com'",
      ),
    );
    expect(
      copiedCommands,
      contains(
        "openclaw config set channels.dev-askman-bricks.BRICKS_PLUGIN_ID 'plugin_node_1'",
      ),
    );
    expect(
      copiedCommands,
      contains(
        "openclaw config set channels.dev-askman-bricks.BRICKS_PLATFORM_TOKEN 'token-123'",
      ),
    );
    expect(copiedCommands, contains('openclaw config validate'));
    expect(copiedCommands, contains('openclaw gateway restart'));
    expect(find.text('OpenClaw commands copied'), findsOneWidget);
  });
}
