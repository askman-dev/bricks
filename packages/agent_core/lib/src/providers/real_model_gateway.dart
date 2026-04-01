import 'dart:convert';

import 'package:agent_sdk_contract/agent_sdk_contract.dart';
import 'package:http/http.dart' as http;

class RealModelGateway {
  RealModelGateway({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<String> generate({
    required AgentSettings settings,
    required String message,
  }) async {
    switch (settings.provider) {
      case 'test':
        return 'Received: $message';
      case 'anthropic':
        return _anthropicGenerate(settings: settings, message: message);
      case 'gemini':
      case 'google_ai_studio':
        return _geminiGenerate(settings: settings, message: message);
      default:
        throw StateError(
          'Unsupported provider: ${settings.provider}. Supported providers: anthropic, gemini, google_ai_studio.',
        );
    }
  }

  Future<String> _anthropicGenerate({
    required AgentSettings settings,
    required String message,
  }) async {
    const apiKey = String.fromEnvironment('BRICKS_ANTHROPIC_API_KEY');
    const endpoint = String.fromEnvironment(
      'BRICKS_ANTHROPIC_BASE_URL',
      defaultValue: 'https://api.anthropic.com',
    );

    if (apiKey.isEmpty) {
      throw StateError('Missing BRICKS_ANTHROPIC_API_KEY.');
    }

    final uri = Uri.parse(endpoint).resolve('/v1/messages');
    final body = jsonEncode({
      'model': settings.model,
      'max_tokens': 1024,
      'system': settings.systemPrompt,
      'messages': [
        {'role': 'user', 'content': message},
      ],
    });

    final response = await _httpClient.post(
      uri,
      headers: {
        'content-type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: body,
    );

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
    const apiKey = String.fromEnvironment('BRICKS_GEMINI_API_KEY');
    const endpoint = String.fromEnvironment(
      'BRICKS_GEMINI_BASE_URL',
      defaultValue: 'https://generativelanguage.googleapis.com',
    );

    if (apiKey.isEmpty) {
      throw StateError('Missing BRICKS_GEMINI_API_KEY.');
    }

    final uri = Uri.parse(endpoint)
        .resolve('/v1beta/models/${settings.model}:generateContent')
        .replace(
      queryParameters: {'key': apiKey},
    );

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

    final response = await _httpClient.post(
      uri,
      headers: {'content-type': 'application/json'},
      body: body,
    );

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
