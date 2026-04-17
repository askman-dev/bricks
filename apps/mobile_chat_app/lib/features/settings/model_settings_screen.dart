import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'llm_config_service.dart';

/// Displayed as a placeholder hint when the active config has a stored API key
/// that is intentionally not shown for security reasons.
const kApiKeyStoredHint = '(已设置，出于安全原因未显示)';

class ModelSettingsScreen extends StatefulWidget {
  const ModelSettingsScreen({super.key, LlmConfigService? service})
      : _service = service ?? const LlmConfigService();

  final LlmConfigService _service;

  @override
  State<ModelSettingsScreen> createState() => _ModelSettingsScreenState();
}

class _ModelSettingsScreenState extends State<ModelSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final LlmConfigService _service;
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _defaultModelController = TextEditingController();

  final List<LlmConfig> _configs = [];
  int _activeConfigIndex = 0;

  LlmProvider _provider = LlmProvider.anthropic;
  bool _loading = true;
  bool _saving = false;
  bool _deleting = false;
  bool _showApiKey = false;

  @override
  void initState() {
    super.initState();
    _service = widget._service;
    _load();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _defaultModelController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final configs = await _service.fetchConfigs();
      if (!mounted) return;
      _configs
        ..clear()
        ..addAll(configs);

      if (_configs.isEmpty) {
        _configs.add(_blankConfig(slotId: 'config-1', isDefault: true));
      }

      _activeConfigIndex = _configs.indexWhere((cfg) => cfg.isDefault);
      if (_activeConfigIndex < 0) {
        _activeConfigIndex = 0;
      }
      _hydrateForm(_configs[_activeConfigIndex]);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load model settings')),
        );
      }
      _configs
        ..clear()
        ..add(_blankConfig(slotId: 'config-1', isDefault: true));
      _activeConfigIndex = 0;
      _hydrateForm(_configs.first);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  LlmConfig _blankConfig({required String slotId, required bool isDefault}) {
    const provider = LlmProvider.anthropic;
    return LlmConfig(
      slotId: slotId,
      provider: provider,
      baseUrl: _defaultBaseUrl(provider),
      apiKey: '',
      defaultModel: _defaultModel(provider),
      isDefault: isDefault,
    );
  }

  void _hydrateForm(LlmConfig config) {
    _provider = config.provider;
    _baseUrlController.text = config.baseUrl;
    _apiKeyController.clear();
    _defaultModelController.text = config.defaultModel;
  }

  String _activeConfigIdHint() {
    final config = _configs[_activeConfigIndex];
    return config.id == null ? 'Will be created on save' : config.id!;
  }

  String _activeSlotIdHint() {
    final modelName = _defaultModelController.text.trim();
    if (modelName.isEmpty) {
      return _configs[_activeConfigIndex].slotId;
    }
    return LlmConfigService.normalizedSlotIdForModel(modelName);
  }

  void _setDefaultsForProvider(LlmProvider provider) {
    _baseUrlController.text = _defaultBaseUrl(provider);
    _defaultModelController.text = _defaultModel(provider);
  }

  static String _defaultBaseUrl(LlmProvider provider) {
    switch (provider) {
      case LlmProvider.googleAiStudio:
        return 'https://generativelanguage.googleapis.com';
      case LlmProvider.anthropic:
        return 'https://api.anthropic.com';
    }
  }

  static String _defaultModel(LlmProvider provider) {
    switch (provider) {
      case LlmProvider.googleAiStudio:
        return 'gemini-flash-latest';
      case LlmProvider.anthropic:
        return 'claude-sonnet-4-5';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final current = _configs[_activeConfigIndex];
    try {
      final saved = await _service.save(
        current.copyWith(
          provider: _provider,
          baseUrl: _baseUrlController.text.trim(),
          apiKey: _apiKeyController.text.trim(),
          defaultModel: _defaultModelController.text.trim(),
          isDefault: true,
        ),
      );

      if (!mounted) return;

      _configs[_activeConfigIndex] = saved;
      for (var i = 0; i < _configs.length; i++) {
        if (i != _activeConfigIndex) {
          _configs[i] = _configs[i].copyWith(isDefault: false);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model settings saved')),
      );
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save model settings')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteCurrentConfig() async {
    if (_deleting || _saving) return;
    final current = _configs[_activeConfigIndex];

    if (current.id != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete configuration?'),
          content: const Text('This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      if (!mounted) return;
    }

    setState(() => _deleting = true);
    try {
      if (current.id != null) {
        await _service.deleteConfig(current.id!);
      }
      if (!mounted) return;

      _configs.removeAt(_activeConfigIndex);
      if (_configs.isEmpty) {
        _configs.add(_blankConfig(slotId: 'config-1', isDefault: true));
        _activeConfigIndex = 0;
      } else {
        _activeConfigIndex =
            (_activeConfigIndex - 1).clamp(0, _configs.length - 1);
        for (var i = 0; i < _configs.length; i++) {
          _configs[i] =
              _configs[i].copyWith(isDefault: i == _activeConfigIndex);
        }
      }
      _hydrateForm(_configs[_activeConfigIndex]);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model configuration deleted')),
      );
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete model configuration')),
      );
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
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

  Widget _buildConfigSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(_configs.length, (index) {
        final config = _configs[index];
        final modelName = config.defaultModel.trim();
        final label = modelName.isEmpty ? 'Config ${index + 1}' : modelName;
        return ChoiceChip(
          label: Text(label),
          selected: index == _activeConfigIndex,
          onSelected: (_) {
            setState(() {
              _activeConfigIndex = index;
              _hydrateForm(_configs[index]);
            });
          },
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Model Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('Configs'),
                  const SizedBox(height: 8),
                  _buildConfigSelector(),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<LlmProvider>(
                    initialValue: _provider,
                    decoration: const InputDecoration(labelText: 'Provider'),
                    items: const [
                      DropdownMenuItem(
                        value: LlmProvider.anthropic,
                        child: Text('Anthropic'),
                      ),
                      DropdownMenuItem(
                        value: LlmProvider.googleAiStudio,
                        child: Text('Google AI Studio'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _provider = value;
                        _setDefaultsForProvider(value);
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _baseUrlController,
                    decoration: InputDecoration(
                      labelText: 'Base URL',
                      suffixIcon: IconButton(
                        tooltip: 'Copy API URL',
                        icon: const Icon(Icons.copy_outlined),
                        onPressed: () {
                          _copyToClipboard(
                            value: _baseUrlController.text,
                            emptyMessage: 'API URL is empty',
                            successMessage: 'API URL copied',
                          );
                        },
                      ),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'Base URL is required';
                      final uri = Uri.tryParse(text);
                      if (uri == null || !uri.hasScheme) {
                        return 'Enter a valid URL';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _apiKeyController,
                    obscureText: !_showApiKey,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      hintText: _configs[_activeConfigIndex].apiKey.isNotEmpty
                          ? kApiKeyStoredHint
                          : null,
                      hintStyle: _configs[_activeConfigIndex].apiKey.isNotEmpty
                          ? TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color,
                            )
                          : null,
                      helperText: _configs[_activeConfigIndex].id == null
                          ? null
                          : 'Leave blank to keep your existing key',
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Copy API Key',
                            icon: const Icon(Icons.copy_outlined),
                            onPressed: () {
                              _copyToClipboard(
                                value: _apiKeyController.text,
                                emptyMessage: 'API Key is empty',
                                successMessage: 'API Key copied',
                              );
                            },
                          ),
                          IconButton(
                            tooltip:
                                _showApiKey ? 'Hide API key' : 'Show API key',
                            icon: Icon(
                              _showApiKey
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () =>
                                setState(() => _showApiKey = !_showApiKey),
                          ),
                        ],
                      ),
                    ),
                    validator: (value) {
                      if (_configs[_activeConfigIndex].id == null &&
                          (value?.trim() ?? '').isEmpty) {
                        return 'API Key is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _defaultModelController,
                    decoration:
                        const InputDecoration(labelText: 'Default Model'),
                    onChanged: (value) {
                      final trimmed = value.trim();
                      final currentSlotId = _configs[_activeConfigIndex].slotId;
                      _configs[_activeConfigIndex] =
                          _configs[_activeConfigIndex].copyWith(
                        defaultModel: trimmed,
                        slotId: trimmed.isEmpty
                            ? currentSlotId
                            : LlmConfigService.normalizedSlotIdForModel(
                                trimmed,
                              ),
                      );
                      setState(() {});
                    },
                    validator: (value) {
                      if ((value?.trim() ?? '').isEmpty) {
                        return 'Default model is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Config ID: ${_activeConfigIdHint()}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Config Slot: ${_activeSlotIdHint()}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: (_saving || _deleting)
                            ? null
                            : _deleteCurrentConfig,
                        icon: _deleting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.delete_outline),
                        label: Text(_deleting ? 'Deleting...' : 'Delete'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: (_saving || _deleting) ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Saving...' : 'Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
