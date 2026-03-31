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
    required this.provider,
    required this.baseUrl,
    required this.apiKey,
    required this.defaultModel,
    this.isDefault = true,
  });

  final String? id;
  final LlmProvider provider;
  final String baseUrl;
  final String apiKey;
  final String defaultModel;
  final bool isDefault;

  LlmConfig copyWith({
    String? id,
    LlmProvider? provider,
    String? baseUrl,
    String? apiKey,
    String? defaultModel,
    bool? isDefault,
  }) {
    return LlmConfig(
      id: id ?? this.id,
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

  Future<LlmConfig?> fetchDefault() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) return null;

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
      return null;
    }

    final configs = decoded.whereType<Map<String, dynamic>>().toList();
    if (configs.isEmpty) return null;
    final selected = configs.firstWhere(
      (cfg) => cfg['is_default'] == true,
      orElse: () => configs.first,
    );

    return _fromApiConfig(selected);
  }

  Future<void> save(LlmConfig config) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }

    final configPayload = <String, dynamic>{
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
      'is_default': config.isDefault,
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
  }

  LlmConfig _fromApiConfig(Map<String, dynamic> config) {
    final rawConfig = config['config'];
    final map =
        rawConfig is Map<String, dynamic> ? rawConfig : <String, dynamic>{};
    final preferences = map['model_preferences'];
    final modelPrefs =
        preferences is Map<String, dynamic> ? preferences : <String, dynamic>{};

    final provider = LlmProviderWire.fromWireValue(
      (config['provider'] as String?) ?? 'anthropic',
    );
    return LlmConfig(
      id: config['id'] as String?,
      provider: provider,
      baseUrl: (map['endpoint'] as String?) ?? _defaultBaseUrl(provider),
      apiKey: '',
      defaultModel:
          (modelPrefs['default_model'] as String?) ?? 'claude-sonnet-4-5',
      isDefault: (config['is_default'] as bool?) ?? false,
    );
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
