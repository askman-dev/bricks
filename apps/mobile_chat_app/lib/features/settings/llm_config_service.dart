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
    this.models = const [],
    this.isDefault = false,
  });

  final String? id;
  final String slotId;
  final LlmProvider provider;
  final String baseUrl;
  final String apiKey;
  final String defaultModel;
  final List<String> models;
  final bool isDefault;

  LlmConfig copyWith({
    String? id,
    String? slotId,
    LlmProvider? provider,
    String? baseUrl,
    String? apiKey,
    String? defaultModel,
    List<String>? models,
    bool? isDefault,
  }) {
    return LlmConfig(
      id: id ?? this.id,
      slotId: slotId ?? this.slotId,
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      defaultModel: defaultModel ?? this.defaultModel,
      models: models ?? this.models,
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
    final base = resolveBaseUrl();
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  static String resolveBaseUrl() {
    if (_apiBaseUrl.isNotEmpty) return _apiBaseUrl;
    if (kIsWeb) return Uri.base.origin;
    return 'http://localhost:3000';
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

  Future<void> deleteConfig(String id) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }

    final encodedId = Uri.encodeComponent(id);

    final response = await http.delete(
      _buildUri('/api/config/$encodedId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
          'Failed to delete model settings (${response.statusCode})');
    }
  }

  Future<List<PlatformNodeConfig>> fetchPlatformNodes() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }

    final response = await http.get(
      _buildUri('/api/config/nodes'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception(
          'Failed to fetch platform nodes (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return const [];
    final map = Map<String, dynamic>.from(decoded);
    final nodesRaw = map['nodes'];
    if (nodesRaw is! List) return const [];
    return nodesRaw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(
          (item) => PlatformNodeConfig(
            nodeId: (item['nodeId'] as String?) ?? '',
            displayName: (item['displayName'] as String?) ?? '',
            pluginId: (item['pluginId'] as String?) ?? '',
          ),
        )
        .where((node) => node.nodeId.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<PlatformNodeConfig> createPlatformNode({String? displayName}) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }

    final response = await http.post(
      _buildUri('/api/config/nodes'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        if (displayName != null) 'displayName': displayName.trim(),
      }),
    );
    if (response.statusCode != 201) {
      throw Exception(
          'Failed to create platform node (${response.statusCode})');
    }
    final raw = jsonDecode(response.body);
    final map =
        raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
    return PlatformNodeConfig(
      nodeId: (map['nodeId'] as String?) ?? '',
      displayName: (map['displayName'] as String?) ?? '',
      pluginId: (map['pluginId'] as String?) ?? '',
    );
  }

  Future<PlatformNodeConfig> renamePlatformNode({
    required String nodeId,
    required String displayName,
  }) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }

    final response = await http.patch(
      _buildUri('/api/config/nodes/${Uri.encodeComponent(nodeId)}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'displayName': displayName.trim()}),
    );
    if (response.statusCode != 200) {
      throw Exception(
          'Failed to rename platform node (${response.statusCode})');
    }
    final raw = jsonDecode(response.body);
    final map =
        raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
    return PlatformNodeConfig(
      nodeId: (map['nodeId'] as String?) ?? nodeId,
      displayName: (map['displayName'] as String?) ?? displayName,
      pluginId: (map['pluginId'] as String?) ?? '',
    );
  }

  Future<PlatformTokenBundle> fetchPlatformToken({
    String? nodeId,
    String pluginId = 'plugin_local_main',
  }) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }

    final response = await http.get(
      _buildUri('/api/config/platform-token', {
        if (nodeId != null && nodeId.trim().isNotEmpty) 'nodeId': nodeId.trim(),
        if (nodeId == null || nodeId.trim().isEmpty) 'pluginId': pluginId,
      }),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to fetch platform token (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Invalid platform token payload');
    }
    final map = Map<String, dynamic>.from(decoded);
    final scopesRaw = map['scopes'];
    final scopes = scopesRaw is List
        ? scopesRaw
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
        : const <String>[];

    final rawBaseUrl = (map['baseUrl'] as String?)?.trim();

    return PlatformTokenBundle(
      nodeId: (map['nodeId'] as String?) ?? nodeId ?? '',
      nodeName: (map['nodeName'] as String?) ?? '',
      token: (map['token'] as String?) ?? '',
      pluginId: (map['pluginId'] as String?) ?? pluginId,
      baseUrl: rawBaseUrl != null && rawBaseUrl.isNotEmpty
          ? rawBaseUrl
          : resolveBaseUrl(),
      scopes: scopes,
      expiresIn: (map['expiresIn'] as String?) ?? '',
    );
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
    final defaultModelRaw =
        ((modelPrefs['default_model'] as String?) ?? _defaultModel(provider))
            .trim();
    final defaultModel =
        defaultModelRaw.isNotEmpty ? defaultModelRaw : _defaultModel(provider);
    final rawModels = modelPrefs['models'];
    final models = <String>[];
    final seen = <String>{};
    void addModel(String model) {
      final normalized = model.trim();
      if (normalized.isEmpty) return;
      final dedupeKey = normalized.toLowerCase();
      if (seen.add(dedupeKey)) {
        models.add(normalized);
      }
    }

    addModel(defaultModel);
    if (rawModels is List) {
      for (final item in rawModels.whereType<String>()) {
        addModel(item);
      }
    }
    return LlmConfig(
      id: configId,
      slotId: slotId != null && slotId.isNotEmpty
          ? slotId
          : normalizedSlotIdForModel(defaultModel),
      provider: provider,
      baseUrl: (map['endpoint'] as String?) ?? _defaultBaseUrl(provider),
      apiKey: ((map['api_key'] as String?) ?? '').trim(),
      defaultModel: defaultModel,
      models: models,
      isDefault: _parseIsDefaultValue(config['is_default']),
    );
  }

  static bool _parseIsDefaultValue(dynamic value) {
    if (value is num) {
      if (value == 1) return true;
      if (value == 0) return false;
      debugPrint(
        'Unexpected is_default numeric value: $value (treating as false)',
      );
      return false;
    }
    if (value is String) {
      final normalized = value.trim();
      if (normalized == '1') return true;
      if (normalized == '0') return false;
      debugPrint(
        'Unexpected is_default string value: $value (treating as false)',
      );
      return false;
    }
    debugPrint(
      'Unexpected is_default non-numeric value: $value (treating as false)',
    );
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

class PlatformTokenBundle {
  const PlatformTokenBundle({
    required this.nodeId,
    required this.nodeName,
    required this.token,
    required this.pluginId,
    required this.baseUrl,
    required this.scopes,
    required this.expiresIn,
  });

  final String nodeId;
  final String nodeName;
  final String token;
  final String pluginId;
  final String baseUrl;
  final List<String> scopes;
  final String expiresIn;
}

class PlatformNodeConfig {
  const PlatformNodeConfig({
    required this.nodeId,
    required this.displayName,
    required this.pluginId,
  });

  final String nodeId;
  final String displayName;
  final String pluginId;
}
