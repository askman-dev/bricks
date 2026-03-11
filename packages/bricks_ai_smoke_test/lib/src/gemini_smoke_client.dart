import 'dart:convert';
import 'package:http/http.dart' as http;
import 'provider_env_config.dart';
import 'smoke_result.dart';

/// Minimal client for testing Gemini API endpoints.
class GeminiSmokeClient {
  final GeminiEnvConfig config;
  final http.Client? httpClient;

  static const _requestTimeout = Duration(seconds: 30);

  GeminiSmokeClient(this.config, {http.Client? httpClient})
      : httpClient = httpClient ?? http.Client();

  /// Send a minimal test request to the Gemini endpoint.
  ///
  /// Sends a simple prompt requesting a specific response text.
  /// Returns [ProviderSmokeResult] with success status and output.
  Future<ProviderSmokeResult> sendTestRequest({
    String prompt = 'Reply with exactly: gemini-ok',
  }) async {
    try {
      // Gemini API uses query parameter for API key
      final endpoint = config.baseUrl
          .resolve('/v1beta/models/${config.model}:generateContent')
          .replace(queryParameters: {'key': config.apiKey});

      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
      };

      final response = await httpClient!
          .post(
            endpoint,
            headers: {
              'content-type': 'application/json',
            },
            body: json.encode(requestBody),
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        final outputText = _extractGeminiText(responseData);

        return ProviderSmokeResult(
          provider: 'gemini',
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
          provider: 'gemini',
          success: false,
          statusCode: response.statusCode,
          errorMessage: 'HTTP ${response.statusCode}: $errorMessage',
        );
      }
    } catch (e) {
      return ProviderSmokeResult(
        provider: 'gemini',
        success: false,
        errorMessage: _formatError(e),
      );
    }
  }

  /// Extract text content from Gemini API response.
  String _extractGeminiText(Map<String, dynamic> response) {
    final candidates = response['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw FormatException('No candidates in response');
    }

    final firstCandidate = candidates.first as Map<String, dynamic>;
    final content = firstCandidate['content'] as Map<String, dynamic>?;
    if (content == null) {
      throw FormatException('No content in candidate');
    }

    final parts = content['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw FormatException('No parts in content');
    }

    final firstPart = parts.first as Map<String, dynamic>;
    return firstPart['text'] as String;
  }

  /// Format error for user-friendly display.
  String _formatError(Object error) {
    if (error is http.ClientException) {
      return 'Network error: ${error.message}. Check TEST_GEMINI_BASE_URL.';
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
