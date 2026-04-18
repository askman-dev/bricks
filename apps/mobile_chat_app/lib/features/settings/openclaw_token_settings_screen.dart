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
    return '''
Send this information to OpenClaw plugin setup, or paste the JSON snippet into ~/.openclaw/openclaw.json (replace <CHANNEL_ID>):

{
  "channels": {
    "<CHANNEL_ID>": {
      "BRICKS_BASE_URL": "${bundle.baseUrl}",
      "BRICKS_PLUGIN_ID": "${bundle.pluginId}",
      "BRICKS_PLATFORM_TOKEN": "${bundle.token}"
    }
  }
}

Parameters:
- pluginId: ${bundle.pluginId}
- url: ${bundle.baseUrl}
- scopes: $scopes
- token: ${bundle.token}
''';
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
    final platformTokenBundle = _platformTokenBundle;
    final installInstruction = platformTokenBundle == null
        ? null
        : _buildInstallInstruction(platformTokenBundle);
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
          if (platformTokenBundle != null && installInstruction != null) ...[
            const SizedBox(height: 12),
            Text('Plugin ID: ${platformTokenBundle.pluginId}'),
            const SizedBox(height: 6),
            Text('Base URL: ${platformTokenBundle.baseUrl}'),
            const SizedBox(height: 6),
            Text('Scopes: ${platformTokenBundle.scopes.join(', ')}'),
            const SizedBox(height: 8),
            TextFormField(
              key: ValueKey(platformTokenBundle.token),
              initialValue: platformTokenBundle.token,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Openclaw Token',
                suffixIcon: IconButton(
                  tooltip: 'Copy Openclaw Token',
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () {
                    _copyToClipboard(
                      value: platformTokenBundle.token,
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
              'Share the following information with OpenClaw to finish plugin configuration.',
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
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
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
            ),
          ],
        ],
      ),
    );
  }
}
