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
          if (_platformTokenBundle != null) ...[
            const SizedBox(height: 12),
            Text('Plugin ID: ${_platformTokenBundle!.pluginId}'),
            const SizedBox(height: 6),
            Text('Base URL: ${_platformTokenBundle!.baseUrl}'),
            const SizedBox(height: 6),
            Text('Scopes: ${_platformTokenBundle!.scopes.join(', ')}'),
            const SizedBox(height: 8),
            TextFormField(
              key: ValueKey(_platformTokenBundle!.token),
              initialValue: _platformTokenBundle!.token,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Openclaw Token',
                suffixIcon: IconButton(
                  tooltip: 'Copy Openclaw Token',
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () {
                    _copyToClipboard(
                      value: _platformTokenBundle!.token,
                      emptyMessage: 'Openclaw Token is empty',
                      successMessage: 'Openclaw Token copied',
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
