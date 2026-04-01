import 'dart:convert';
import 'dart:io';

import 'package:agent_sdk_contract/agent_sdk_contract.dart';
import 'package:http/http.dart' as http;

class RealModelGateway {
  /// Provider name used for the synthetic test stub (no real HTTP calls).
  static const String testProvider = 'test';

  RealModelGateway({http.Client? httpClient, Map<String, String>? environment})
      : _httpClient = httpClient ?? http.Client(),
        _environment = _buildEnvironment(environment);

  final http.Client _httpClient;
  final Map<String, String> _environment;

  static Map<String, String> _buildEnvironment(Map<String, String>? override) {
    if (override != null) return override;

    final values = <String, String>{
      if (const String.fromEnvironment('BRICKS_ANTHROPIC_API_KEY').isNotEmpty)
        'BRICKS_ANTHROPIC_API_KEY':
            const String.fromEnvironment('BRICKS_ANTHROPIC_API_KEY'),
      if (const String.fromEnvironment('BRICKS_ANTHROPIC_BASE_URL').isNotEmpty)
        'BRICKS_ANTHROPIC_BASE_URL':
            const String.fromEnvironment('BRICKS_ANTHROPIC_BASE_URL'),
      if (const String.fromEnvironment('BRICKS_GEMINI_API_KEY').isNotEmpty)
        'BRICKS_GEMINI_API_KEY':
            const String.fromEnvironment('BRICKS_GEMINI_API_KEY'),
      if (const String.fromEnvironment('BRICKS_GEMINI_BASE_URL').isNotEmpty)
        'BRICKS_GEMINI_BASE_URL':
            const String.fromEnvironment('BRICKS_GEMINI_BASE_URL'),
    };

    try {
      values.addAll(Platform.environment);
    } on UnsupportedError {
      // Platform environment variables are unavailable on web.
    }

    return values;
  }

  Future<String> generate({
    required AgentSettings settings,
    required String message,
  }) async {
    final backendResult = await _generateViaBackendIfConfigured(
      settings: settings,
      message: message,
    );
    if (backendResult != null) {
      return backendResult;
    }

    switch (settings.provider) {
      case testProvider:
        return 'Received: $message';
      case 'anthropic':
        return _anthropicGenerate(settings: settings, message: message);
      case 'gemini':
      case 'google_ai_studio':
        return _geminiGenerate(settings: settings, message: message);
      default:
        throw StateError(
          'Unsupported provider: ${settings.provider}. Supported providers: test, anthropic, gemini, google_ai_studio.',
        );
    }
  }

  Future<String?> _generateViaBackendIfConfigured({
    required AgentSettings settings,
    required String message,
  }) async {
    final baseUrl = settings.apiBaseUrl?.trim() ?? '';
    final token = settings.authToken?.trim() ?? '';
    if (baseUrl.isEmpty || token.isEmpty) {
      return null;
    }

    final baseUri = _validateBaseUrl(baseUrl, 'AgentSettings.apiBaseUrl');
    final uri = baseUri.replace(path: '/api/llm/chat');
    final provider =
        settings.provider == 'gemini' ? 'google_ai_studio' : settings.provider;
    final payload = <String, dynamic>{
      'provider': provider,
      'model': settings.model,
      'messages': [
        {'role': 'user', 'content': message},
      ],
      if (settings.configId != null && settings.configId!.trim().isNotEmpty)
        'configId': settings.configId!.trim(),
    };
    final response = await _httpClient
        .post(
          uri,
          headers: {
            'content-type': 'application/json',
            'authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Backend chat request failed (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final output = (data is Map<String, dynamic>) ? data['output'] : null;
    if (output is! List || output.isEmpty) {
      throw StateError('Backend chat response missing output.');
    }
    for (final item in output) {
      if (item is Map<String, dynamic> && item['type'] == 'text') {
        final text = item['text'];
        if (text is String && text.trim().isNotEmpty) return text;
      }
    }
    throw StateError('Backend chat response missing text output.');
  }

  /// Validates that [urlStr] is an absolute URL with a scheme of `http` or
  /// `https` and a non-empty host. Throws [StateError] on failure.
  Uri _validateBaseUrl(String urlStr, String envVarName) {
    final uri = Uri.tryParse(urlStr);
    if (uri == null ||
        !uri.isAbsolute ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw StateError(
        'Invalid $envVarName: "$urlStr". Must be an absolute HTTP(S) URL.',
      );
    }
    return uri;
  }

  Future<String> _anthropicGenerate({
    required AgentSettings settings,
    required String message,
  }) async {
    final apiKey = _environment['BRICKS_ANTHROPIC_API_KEY'] ?? '';
    final endpointStr = _environment['BRICKS_ANTHROPIC_BASE_URL'] ??
        'https://api.anthropic.com';

    if (apiKey.isEmpty) {
      throw StateError('Missing BRICKS_ANTHROPIC_API_KEY.');
    }

    final baseUri = _validateBaseUrl(endpointStr, 'BRICKS_ANTHROPIC_BASE_URL');
    final uri = baseUri.replace(path: '/v1/messages');
    final bodyMap = <String, dynamic>{
      'model': settings.model,
      'max_tokens': 1024,
      'messages': [
        {'role': 'user', 'content': message},
      ],
    };
    if (settings.systemPrompt != null &&
        settings.systemPrompt!.trim().isNotEmpty) {
      bodyMap['system'] = settings.systemPrompt;
    }
    final body = jsonEncode(bodyMap);

    final response = await _httpClient
        .post(
          uri,
          headers: {
            'content-type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Anthropic request failed (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final content = (data is Map<String, dynamic>) ? data['content'] : null;
    if (content is! List || content.isEmpty) {
      throw StateError('Anthropic response missing content.');
    }
    final first = content.first;
    final text = (first is Map<String, dynamic>) ? first['text'] : null;
    if (text is! String || text.trim().isEmpty) {
      throw StateError('Anthropic response text is empty.');
    }
    return text;
  }

  Future<String> _geminiGenerate({
    required AgentSettings settings,
    required String message,
  }) async {
    final apiKey = _environment['BRICKS_GEMINI_API_KEY'] ?? '';
    final endpointStr = _environment['BRICKS_GEMINI_BASE_URL'] ??
        'https://generativelanguage.googleapis.com';

    if (apiKey.isEmpty) {
      throw StateError('Missing BRICKS_GEMINI_API_KEY.');
    }

    final baseUri = _validateBaseUrl(endpointStr, 'BRICKS_GEMINI_BASE_URL');
    // Gemini API requires the API key as a `key` query parameter per the
    // official REST authentication scheme (header-based auth is not supported).
    final uri = baseUri
        .replace(path: '/v1beta/models/${settings.model}:generateContent')
        .replace(queryParameters: {'key': apiKey});

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': message},
          ],
        },
      ],
      if (settings.systemPrompt != null && settings.systemPrompt!.isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': settings.systemPrompt},
          ],
        },
    });

    final response = await _httpClient
        .post(
          uri,
          headers: {'content-type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Gemini request failed (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final candidates =
        (data is Map<String, dynamic>) ? data['candidates'] : null;
    if (candidates is! List || candidates.isEmpty) {
      throw StateError('Gemini response missing candidates.');
    }
    final first = candidates.first;
    final content = (first is Map<String, dynamic>) ? first['content'] : null;
    final parts = (content is Map<String, dynamic>) ? content['parts'] : null;
    if (parts is! List || parts.isEmpty) {
      throw StateError('Gemini response missing text parts.');
    }
    final firstPart = parts.first;
    final text = (firstPart is Map<String, dynamic>) ? firstPart['text'] : null;
    if (text is! String || text.trim().isEmpty) {
      throw StateError('Gemini response text is empty.');
    }
    return text;
  }
}
