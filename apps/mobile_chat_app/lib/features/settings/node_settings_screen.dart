import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'llm_config_service.dart';

class NodeSettingsScreen extends StatefulWidget {
  const NodeSettingsScreen({super.key, LlmConfigService? service})
      : _service = service ?? const LlmConfigService();

  final LlmConfigService _service;

  @override
  State<NodeSettingsScreen> createState() => _NodeSettingsScreenState();
}

class _NodeSettingsScreenState extends State<NodeSettingsScreen> {
  late final LlmConfigService _service;
  bool _loading = false;
  bool _actionLoading = false;
  PlatformTokenBundle? _bundle;
  List<PlatformNodeConfig> _nodes = const [];

  @override
  void initState() {
    super.initState();
    _service = widget._service;
    _loadNodes();
  }

  Future<void> _loadNodes() async {
    setState(() => _loading = true);
    try {
      final nodes = await _service.fetchPlatformNodes();
      if (!mounted) return;
      setState(() => _nodes = nodes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load nodes')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createNode() async {
    if (_actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      await _service.createPlatformNode();
      await _loadNodes();
    } catch (e) {
      debugPrint('_createNode error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create node')),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _renameNode(PlatformNodeConfig node) async {
    final controller = TextEditingController(text: node.displayName);
    final nextName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Node'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Node Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (nextName == null || nextName.trim().isEmpty) return;
    if (_actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      await _service.renamePlatformNode(
          nodeId: node.nodeId, displayName: nextName);
      await _loadNodes();
    } catch (e) {
      debugPrint('_renameNode error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to rename node')),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _copyText(String value, String successMessage) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(successMessage)));
  }

  String _shellQuote(String value) {
    if (value.isEmpty) return "''";
    return "'${value.replaceAll("'", "'\"'\"'")}'";
  }

  String _buildOpenClawCommands(PlatformTokenBundle bundle) {
    return [
      'openclaw config set channels.dev-askman-bricks.BRICKS_BASE_URL ${_shellQuote(bundle.baseUrl)}',
      'openclaw config set channels.dev-askman-bricks.BRICKS_PLUGIN_ID ${_shellQuote(bundle.pluginId)}',
      'openclaw config set channels.dev-askman-bricks.BRICKS_PLATFORM_TOKEN ${_shellQuote(bundle.token)}',
      '',
      'openclaw config validate',
      'openclaw gateway restart',
      'openclaw plugins inspect dev-askman-bricks',
    ].join('\n');
  }

  Future<void> _generateNodeToken(PlatformNodeConfig node) async {
    if (_actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      final bundle = await _service.fetchPlatformToken(nodeId: node.nodeId);
      if (!mounted) return;
      setState(() => _bundle = bundle);
    } catch (e) {
      debugPrint('_generateNodeToken error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate token')),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nodes = _nodes;
    return Scaffold(
      appBar: AppBar(title: const Text('节点')),
      floatingActionButton: nodes.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _actionLoading ? null : _createNode,
              icon: const Icon(Icons.add),
              label: const Text('新增节点'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : nodes.isEmpty
              ? Center(
                  child: FilledButton.icon(
                    onPressed: _actionLoading ? null : _createNode,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('创建第一个节点'),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final node in nodes)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      node.displayName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Rename Node',
                                    onPressed: _actionLoading
                                        ? null
                                        : () => _renameNode(node),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                ],
                              ),
                              Text('plugin: ${node.pluginId}'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _copyText(
                                        node.pluginId, 'Plugin ID copied'),
                                    icon: const Icon(Icons.copy_outlined),
                                    label: const Text('复制 Plugin ID'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _actionLoading
                                        ? null
                                        : () => _generateNodeToken(node),
                                    icon: const Icon(Icons.vpn_key_outlined),
                                    label: const Text('生成 Token'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_bundle != null) ...[
                      const SizedBox(height: 12),
                      SelectableText(_buildOpenClawCommands(_bundle!)),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _copyText(
                          _buildOpenClawCommands(_bundle!),
                          'OpenClaw commands copied',
                        ),
                        icon: const Icon(Icons.copy_all_outlined),
                        label: const Text('复制 OpenClaw 命令'),
                      ),
                    ],
                  ],
                ),
    );
  }
}
