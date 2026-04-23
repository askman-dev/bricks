import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'llm_config_service.dart';

class OpenclawTokenSettingsScreen extends StatefulWidget {
  const OpenclawTokenSettingsScreen({super.key, LlmConfigService? service})
      : _service = service ?? const LlmConfigService();

  final LlmConfigService _service;

  @override
  State<OpenclawTokenSettingsScreen> createState() =>
      _OpenclawTokenSettingsScreenState();
}

class _OpenclawTokenSettingsScreenState
    extends State<OpenclawTokenSettingsScreen> {
  late final LlmConfigService _service;
  bool _loadingPlatformToken = false;
  PlatformTokenBundle? _platformTokenBundle;

  String _buildInstallInstruction(PlatformTokenBundle bundle) {
    final scopes = bundle.scopes.join(', ');
    final buffer = StringBuffer()
      ..writeln('Send this to OpenClaw plugin setup.')
      ..writeln(
        'You can also paste this JSON into ~/.openclaw/openclaw.json (replace <CHANNEL_ID>):',
      )
      ..writeln()
      ..writeln('{')
      ..writeln('  "channels": {')
      ..writeln('    "<CHANNEL_ID>": {')
      ..writeln('      "BRICKS_BASE_URL": "${bundle.baseUrl}",')
      ..writeln('      "BRICKS_PLUGIN_ID": "${bundle.pluginId}",')
      ..writeln('      "BRICKS_PLATFORM_TOKEN": "${bundle.token}"')
      ..writeln('    }')
      ..writeln('  }')
      ..writeln('}')
      ..writeln()
      ..writeln('Parameters:')
      ..writeln('- pluginId: ${bundle.pluginId}')
      ..writeln('- url: ${bundle.baseUrl}')
      ..writeln('- scopes: $scopes')
      ..write('- token: ${bundle.token}');
    return buffer.toString();
  }

  @override
  void initState() {
    super.initState();
    _service = widget._service;
  }

  Future<void> _copyToClipboard({
    required String value,
    required String emptyMessage,
    required String successMessage,
  }) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final text = value.trim();
    messenger.hideCurrentSnackBar();
    if (text.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(emptyMessage)));
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;

    final refreshedMessenger = ScaffoldMessenger.maybeOf(context);
    if (refreshedMessenger == null) return;
    refreshedMessenger.hideCurrentSnackBar();
    refreshedMessenger.showSnackBar(SnackBar(content: Text(successMessage)));
  }

  Future<void> _loadPlatformToken() async {
    if (_loadingPlatformToken) return;
    setState(() => _loadingPlatformToken = true);
    try {
      final bundle = await _service.fetchPlatformToken();
      if (!mounted) return;
      setState(() => _platformTokenBundle = bundle);
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        const SnackBar(content: Text('Openclaw Token generated')),
      );
    } catch (_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        const SnackBar(content: Text('Failed to generate Openclaw Token')),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingPlatformToken = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bundle = _platformTokenBundle;
    final installInstruction =
        bundle == null ? null : _buildInstallInstruction(bundle);
    return Scaffold(
      appBar: AppBar(title: const Text('Openclaw Token')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: _loadingPlatformToken ? null : _loadPlatformToken,
            icon: _loadingPlatformToken
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.vpn_key_outlined),
            label: Text(
                _loadingPlatformToken ? 'Generating...' : 'Openclaw Token'),
          ),
          if (bundle != null && installInstruction != null) ...[
            const SizedBox(height: 12),
            if (bundle.nodeName.trim().isNotEmpty)
              Text('Node: ${bundle.nodeName}'),
            if (bundle.nodeName.trim().isNotEmpty) const SizedBox(height: 6),
            Text('Plugin ID: ${bundle.pluginId}'),
            const SizedBox(height: 6),
            Text('Base URL: ${bundle.baseUrl}'),
            const SizedBox(height: 6),
            Text('Scopes: ${bundle.scopes.join(', ')}'),
            const SizedBox(height: 8),
            TextFormField(
              key: ValueKey(bundle.token.hashCode),
              initialValue: bundle.token,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Openclaw Token',
                suffixIcon: IconButton(
                  tooltip: 'Copy Openclaw Token',
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () {
                    _copyToClipboard(
                      value: bundle.token,
                      emptyMessage: 'Openclaw Token is empty',
                      successMessage: 'Openclaw Token copied',
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Install Instructions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Copy this and send it to OpenClaw plugin setup.',
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('copyInstallInstructionsButton'),
              onPressed: () {
                _copyToClipboard(
                  value: installInstruction,
                  emptyMessage: 'Install instructions are empty',
                  successMessage: 'Install instructions copied',
                );
              },
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Copy Install Instructions'),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                installInstruction,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
