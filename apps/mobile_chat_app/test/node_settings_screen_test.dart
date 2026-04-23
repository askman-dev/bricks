import 'package:flutter/material.dart';
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
  testWidgets('shows empty-state create button when no nodes', (tester) async {
    final service = _FakeNodeService(empty: true);
    await tester
        .pumpWidget(MaterialApp(home: NodeSettingsScreen(service: service)));
    await tester.pumpAndSettle();

    expect(find.text('Create First Node'), findsOneWidget);
  });

  testWidgets('renders node and can generate token instructions',
      (tester) async {
    final service = _FakeNodeService();
    await tester
        .pumpWidget(MaterialApp(home: NodeSettingsScreen(service: service)));
    await tester.pumpAndSettle();

    expect(find.text('openclaw 1'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Generate Token'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Node: openclaw 1'), findsOneWidget);
    expect(find.textContaining('Token: token-123'), findsOneWidget);
  });
}
