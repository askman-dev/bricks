import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../auth/auth_service.dart';

enum LlmProvider { anthropic, googleAiStudio }

extension LlmProviderWire on LlmProvider {
  String get wireValue {
    switch (this) {
      case LlmProvider.anthropic:
        return 'anthropic';
      case LlmProvider.googleAiStudio:
        return 'google_ai_studio';
    }
  }

  static LlmProvider fromWireValue(String value) {
    switch (value) {
      case 'google_ai_studio':
        return LlmProvider.googleAiStudio;
      case 'anthropic':
      default:
        return LlmProvider.anthropic;
    }
  }
}

class LlmConfig {
  const LlmConfig({
    this.id,
    required this.slotId,
    required this.provider,
    required this.baseUrl,
    required this.apiKey,
    required this.defaultModel,
    this.isDefault = false,
  });

  final String? id;
  final String slotId;
  final LlmProvider provider;
  final String baseUrl;
  final String apiKey;
  final String defaultModel;
  final bool isDefault;

  LlmConfig copyWith({
    String? id,
    String? slotId,
    LlmProvider? provider,
    String? baseUrl,
    String? apiKey,
    String? defaultModel,
    bool? isDefault,
  }) {
    return LlmConfig(
      id: id ?? this.id,
      slotId: slotId ?? this.slotId,
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      defaultModel: defaultModel ?? this.defaultModel,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

class LlmConfigService {
  const LlmConfigService();

  static const String _apiBaseUrl = String.fromEnvironment(
    'BRICKS_API_BASE_URL',
    defaultValue: '',
  );

  Uri _buildUri(String path, [Map<String, String>? query]) {
    if (_apiBaseUrl.isNotEmpty) {
      return Uri.parse('$_apiBaseUrl$path').replace(queryParameters: query);
    }
    if (kIsWeb) {
      return Uri.parse('${Uri.base.origin}$path').replace(
        queryParameters: query,
      );
    }
    return Uri.parse('http://localhost:3000$path').replace(
      queryParameters: query,
    );
  }

  Future<List<LlmConfig>> fetchConfigs() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) return const [];

    final response = await http.get(
      _buildUri('/api/config', {'category': 'llm'}),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load model settings (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List || decoded.isEmpty) {
      return const [];
    }

    final configs = decoded
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(_fromApiConfig)
        .toList();

    return configs;
  }

  Future<LlmConfig?> fetchDefault() async {
    final configs = await fetchConfigs();
    if (configs.isEmpty) return null;
    return configs.firstWhere(
      (cfg) => cfg.isDefault,
      orElse: () => configs.first,
    );
  }

  Future<LlmConfig> save(LlmConfig config) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }

    final modelName = config.defaultModel.trim();
    final resolvedSlotId =
        modelName.isEmpty ? config.slotId : normalizedSlotIdForModel(modelName);
    final configPayload = <String, dynamic>{
      'slot_id': resolvedSlotId,
      'endpoint': config.baseUrl,
      'model_preferences': {
        'default_model': config.defaultModel,
      },
    };
    if (config.apiKey.trim().isNotEmpty) {
      configPayload['api_key'] = config.apiKey;
    }

    final payload = jsonEncode({
      'category': 'llm',
      'provider': config.provider.wireValue,
      'config': configPayload,
      'is_default': config.isDefault ? 1 : 0,
    });

    final uri = config.id == null
        ? _buildUri('/api/config')
        : _buildUri('/api/config/${config.id}');
    final request = config.id == null
        ? http.post
        : (Uri u, {Map<String, String>? headers, Object? body}) =>
            http.put(u, headers: headers, body: body);

    final response = await request(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: payload,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to save model settings (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      return config;
    }
    return _fromApiConfig(Map<String, dynamic>.from(decoded));
  }

  LlmConfig _fromApiConfig(Map<String, dynamic> config) {
    final rawConfig = config['config'];
    final map = rawConfig is Map
        ? Map<String, dynamic>.from(rawConfig)
        : <String, dynamic>{};
    final preferences = map['model_preferences'];
    final modelPrefs = preferences is Map
        ? Map<String, dynamic>.from(preferences)
        : <String, dynamic>{};

    final provider = LlmProviderWire.fromWireValue(
      (config['provider'] as String?) ?? 'anthropic',
    );

    final configId = config['id']?.toString();
    final slotId = (map['slot_id'] as String?)?.trim();
    final defaultModel =
        (modelPrefs['default_model'] as String?) ?? _defaultModel(provider);
    return LlmConfig(
      id: configId,
      slotId: slotId != null && slotId.isNotEmpty
          ? slotId
          : normalizedSlotIdForModel(defaultModel),
      provider: provider,
      baseUrl: (map['endpoint'] as String?) ?? _defaultBaseUrl(provider),
      apiKey: '',
      defaultModel: defaultModel,
      isDefault: _parseIsDefaultNumber(config['is_default']),
    );
  }

  static bool _parseIsDefaultNumber(dynamic value) {
    if (value is num) {
      if (value == 1) return true;
      if (value == 0) return false;
      debugPrint(
        'Unexpected is_default numeric value: $value (treating as false)',
      );
      return false;
    }
    // Narrow fallback in case backend adapter returns bool in some environments.
    if (value is bool) return value;
    return false;
  }

  static String normalizedSlotIdForModel(String modelName) {
    final normalized = modelName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    if (normalized.isEmpty) {
      return 'slot-${DateTime.now().millisecondsSinceEpoch}';
    }
    return normalized;
  }

  static String _defaultModel(LlmProvider provider) {
    switch (provider) {
      case LlmProvider.googleAiStudio:
        return 'gemini-flash-latest';
      case LlmProvider.anthropic:
        return 'claude-sonnet-4-5';
    }
  }

  static String _defaultBaseUrl(LlmProvider provider) {
    switch (provider) {
      case LlmProvider.googleAiStudio:
        return 'https://generativelanguage.googleapis.com';
      case LlmProvider.anthropic:
        return 'https://api.anthropic.com';
    }
  }
}
