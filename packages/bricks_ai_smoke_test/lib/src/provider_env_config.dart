import 'dart:io';

/// Configuration for Anthropic-compatible AI providers loaded from environment.
class AnthropicEnvConfig {
  /// Base URL for the Anthropic-compatible API.
  final Uri baseUrl;

  /// API key for authentication.
  final String apiKey;

  /// Model ID to use for requests.
  final String model;

  const AnthropicEnvConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  /// Load configuration from environment variables.
  ///
  /// Required variables:
  /// - TEST_ANTHROPIC_API_KEY
  ///
  /// Optional variables:
  /// - TEST_ANTHROPIC_BASE_URL (defaults to https://api.anthropic.com)
  /// - TEST_ANTHROPIC_MODEL (defaults to claude-3-haiku-20240307)
  ///
  /// Throws [ConfigError] if required variables are missing or invalid.
  factory AnthropicEnvConfig.fromEnvironment(
      [Map<String, String>? environment]) {
    final env = environment ?? Platform.environment;

    // Required: API key
    final apiKey = env['TEST_ANTHROPIC_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw ConfigError(
        'Missing required environment variable: TEST_ANTHROPIC_API_KEY',
      );
    }

    // Optional: Base URL with default
    final baseUrlStr =
        env['TEST_ANTHROPIC_BASE_URL'] ?? 'https://api.anthropic.com';
    final baseUrl = Uri.tryParse(baseUrlStr);
    if (baseUrl == null) {
      throw ConfigError(
        'Invalid TEST_ANTHROPIC_BASE_URL: $baseUrlStr',
      );
    }

    // Optional: Model with default
    final model = env['TEST_ANTHROPIC_MODEL'] ?? 'claude-3-haiku-20240307';

    return AnthropicEnvConfig(
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
    );
  }
}

/// Configuration for Gemini AI provider loaded from environment.
class GeminiEnvConfig {
  /// Base URL for the Gemini API.
  final Uri baseUrl;

  /// API key for authentication.
  final String apiKey;

  /// Model ID to use for requests.
  final String model;

  const GeminiEnvConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  /// Load configuration from environment variables.
  ///
  /// Required variables:
  /// - TEST_GEMINI_API_KEY
  ///
  /// Optional variables:
  /// - TEST_GEMINI_BASE_URL (defaults to https://generativelanguage.googleapis.com)
  /// - TEST_GEMINI_MODEL (defaults to gemini-1.5-flash)
  ///
  /// Throws [ConfigError] if required variables are missing or invalid.
  factory GeminiEnvConfig.fromEnvironment([Map<String, String>? environment]) {
    final env = environment ?? Platform.environment;

    // Required: API key
    final apiKey = env['TEST_GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw ConfigError(
        'Missing required environment variable: TEST_GEMINI_API_KEY',
      );
    }

    // Optional: Base URL with default
    final baseUrlStr = env['TEST_GEMINI_BASE_URL'] ??
        'https://generativelanguage.googleapis.com';
    final baseUrl = Uri.tryParse(baseUrlStr);
    if (baseUrl == null) {
      throw ConfigError(
        'Invalid TEST_GEMINI_BASE_URL: $baseUrlStr',
      );
    }

    // Optional: Model with default
    final model = env['TEST_GEMINI_MODEL'] ?? 'gemini-1.5-flash';

    return GeminiEnvConfig(
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
    );
  }
}

/// Exception thrown when configuration loading fails.
class ConfigError implements Exception {
  final String message;

  ConfigError(this.message);

  @override
  String toString() => 'ConfigError: $message';
}
