import 'dart:convert';
import 'package:http/http.dart' as http;
import 'provider_env_config.dart';
import 'smoke_result.dart';

/// Minimal client for testing Anthropic-compatible API endpoints.
class AnthropicSmokeClient {
  final AnthropicEnvConfig config;
  final http.Client? httpClient;

  static const _requestTimeout = Duration(seconds: 30);

  AnthropicSmokeClient(this.config, {http.Client? httpClient})
      : httpClient = httpClient ?? http.Client();

  /// Send a minimal test request to the Anthropic-compatible endpoint.
  ///
  /// Sends a simple prompt requesting a specific response text.
  /// Returns [ProviderSmokeResult] with success status and output.
  Future<ProviderSmokeResult> sendTestRequest({
    String prompt = 'Reply with exactly: anthropic-ok',
    int maxTokens = 1024,
  }) async {
    try {
      final endpoint = config.baseUrl.resolve('/v1/messages');

      final requestBody = {
        'model': config.model,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'max_tokens': maxTokens,
      };

      // Sanitize API key for logging (show only first 8 and last 4 chars)
      final sanitizedKey = _sanitizeApiKey(config.apiKey);

      final response = await httpClient!
          .post(
            endpoint,
            headers: {
              'x-api-key': config.apiKey,
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
            },
            body: json.encode(requestBody),
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        final outputText = _extractAnthropicText(responseData);

        return ProviderSmokeResult(
          provider: 'anthropic',
          success: true,
          statusCode: response.statusCode,
          outputText: outputText,
        );
      } else {
        // Parse error message if available
        String errorMessage;
        try {
          final errorData = json.decode(response.body) as Map<String, dynamic>;
          errorMessage = errorData['error']?['message'] ?? response.body;
        } catch (_) {
          errorMessage = response.body;
        }

        return ProviderSmokeResult(
          provider: 'anthropic',
          success: false,
          statusCode: response.statusCode,
          errorMessage: 'HTTP ${response.statusCode}: $errorMessage',
        );
      }
    } catch (e) {
      return ProviderSmokeResult(
        provider: 'anthropic',
        success: false,
        errorMessage: _formatError(e),
      );
    }
  }

  /// Extract text content from Anthropic API response.
  String _extractAnthropicText(Map<String, dynamic> response) {
    final content = response['content'] as List<dynamic>?;
    if (content == null || content.isEmpty) {
      throw FormatException('No content in response');
    }

    final textBlock = content.first as Map<String, dynamic>;
    if (textBlock['type'] != 'text') {
      throw FormatException('Expected text block, got ${textBlock['type']}');
    }

    return textBlock['text'] as String;
  }

  /// Sanitize API key for safe logging.
  String _sanitizeApiKey(String key) {
    if (key.length <= 12) return '***';
    return '${key.substring(0, 8)}...${key.substring(key.length - 4)}';
  }

  /// Format error for user-friendly display.
  String _formatError(Object error) {
    if (error is http.ClientException) {
      return 'Network error: ${error.message}. Check TEST_ANTHROPIC_BASE_URL.';
    } else if (error is FormatException) {
      return 'Response parsing error: ${error.message}';
    } else {
      return 'Unexpected error: $error';
    }
  }

  void dispose() {
    httpClient?.close();
  }
}
