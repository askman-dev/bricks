import 'package:flutter/material.dart';

import 'llm_config_service.dart';

class ModelSettingsScreen extends StatefulWidget {
  const ModelSettingsScreen({super.key});

  @override
  State<ModelSettingsScreen> createState() => _ModelSettingsScreenState();
}

class _ModelSettingsScreenState extends State<ModelSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = const LlmConfigService();
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _defaultModelController = TextEditingController();

  LlmProvider _provider = LlmProvider.anthropic;
  String? _configId;
  bool _loading = true;
  bool _saving = false;
  bool _showApiKey = false;

  @override
  void initState() {
    super.initState();
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
      final config = await _service.fetchDefault();
      if (!mounted) return;
      if (config != null) {
        _provider = config.provider;
        _configId = config.id;
        _baseUrlController.text = config.baseUrl;
        _apiKeyController.text = config.apiKey;
        _defaultModelController.text = config.defaultModel;
      } else {
        _setDefaultsForProvider(_provider);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load model settings')),
        );
      }
      _setDefaultsForProvider(_provider);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
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
        return 'gemini-2.5-pro';
      case LlmProvider.anthropic:
        return 'claude-sonnet-4-5';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _service.save(
        LlmConfig(
          id: _configId,
          provider: _provider,
          baseUrl: _baseUrlController.text.trim(),
          apiKey: _apiKeyController.text.trim(),
          defaultModel: _defaultModelController.text.trim(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model settings saved')),
      );
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
                    decoration: const InputDecoration(labelText: 'Base URL'),
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
                      helperText: _configId == null
                          ? null
                          : 'Leave blank to keep your existing key',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showApiKey ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _showApiKey = !_showApiKey),
                      ),
                    ),
                    validator: (value) {
                      if (_configId == null && (value?.trim() ?? '').isEmpty) {
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
                    validator: (value) {
                      if ((value?.trim() ?? '').isEmpty) {
                        return 'Default model is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving...' : 'Save'),
                  ),
                ],
              ),
            ),
    );
  }
}
