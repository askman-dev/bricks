import 'package:bricks_ai_smoke_test/bricks_ai_smoke_test.dart';
import 'package:test/test.dart';

void main() {
  group('AnthropicEnvConfig', () {
    // Case A1: loads Anthropic config from environment
    test('loads config successfully with all required env vars', () {
      final testEnv = {
        'TEST_ANTHROPIC_API_KEY': 'test-key-12345',
        'TEST_ANTHROPIC_BASE_URL': 'https://api.anthropic.com',
        'TEST_ANTHROPIC_MODEL': 'claude-3-haiku-20240307',
      };

      final config = AnthropicEnvConfig.fromEnvironment(testEnv);

      expect(config.apiKey, equals('test-key-12345'));
      expect(config.baseUrl.toString(), equals('https://api.anthropic.com'));
      expect(config.model, equals('claude-3-haiku-20240307'));
    });

    // Case A1.1: uses default base URL if not provided
    test('uses default base URL when not provided', () {
      final testEnv = {
        'TEST_ANTHROPIC_API_KEY': 'test-key-12345',
      };

      final config = AnthropicEnvConfig.fromEnvironment(testEnv);

      expect(config.apiKey, equals('test-key-12345'));
      expect(config.baseUrl.toString(), equals('https://api.anthropic.com'));
      expect(config.model, equals('claude-3-haiku-20240307'));
    });

    // Case A3: missing Anthropic env vars fails clearly
    test('throws ConfigError when API key is missing', () {
      final testEnv = <String, String>{};

      expect(
        () => AnthropicEnvConfig.fromEnvironment(testEnv),
        throwsA(isA<ConfigError>().having(
          (e) => e.message,
          'message',
          contains('TEST_ANTHROPIC_API_KEY'),
        )),
      );
    });

    test('throws ConfigError when API key is empty', () {
      final testEnv = {
        'TEST_ANTHROPIC_API_KEY': '',
      };

      expect(
        () => AnthropicEnvConfig.fromEnvironment(testEnv),
        throwsA(isA<ConfigError>().having(
          (e) => e.message,
          'message',
          contains('TEST_ANTHROPIC_API_KEY'),
        )),
      );
    });

    // Case A3.1: invalid base URL format fails clearly
    test('throws ConfigError when base URL is invalid', () {
      final testEnv = {
        'TEST_ANTHROPIC_API_KEY': 'test-key-12345',
        'TEST_ANTHROPIC_BASE_URL': 'not-a-valid-url',
      };

      expect(
        () => AnthropicEnvConfig.fromEnvironment(testEnv),
        throwsA(isA<ConfigError>().having(
          (e) => e.message,
          'message',
          contains('Invalid TEST_ANTHROPIC_BASE_URL'),
        )),
      );
    });
  });

  group('GeminiEnvConfig', () {
    // Case A2: loads Gemini config from environment
    test('loads config successfully with all required env vars', () {
      final testEnv = {
        'TEST_GEMINI_API_KEY': 'test-gemini-key-67890',
        'TEST_GEMINI_BASE_URL': 'https://generativelanguage.googleapis.com',
        'TEST_GEMINI_MODEL': 'gemini-1.5-flash',
      };

      final config = GeminiEnvConfig.fromEnvironment(testEnv);

      expect(config.apiKey, equals('test-gemini-key-67890'));
      expect(config.baseUrl.toString(),
          equals('https://generativelanguage.googleapis.com'));
      expect(config.model, equals('gemini-1.5-flash'));
    });

    // Case A2.1: uses default base URL if not provided
    test('uses default base URL when not provided', () {
      final testEnv = {
        'TEST_GEMINI_API_KEY': 'test-gemini-key-67890',
      };

      final config = GeminiEnvConfig.fromEnvironment(testEnv);

      expect(config.apiKey, equals('test-gemini-key-67890'));
      expect(config.baseUrl.toString(),
          equals('https://generativelanguage.googleapis.com'));
      expect(config.model, equals('gemini-1.5-flash'));
    });

    // Case A4: missing Gemini env vars fails clearly
    test('throws ConfigError when API key is missing', () {
      final testEnv = <String, String>{};

      expect(
        () => GeminiEnvConfig.fromEnvironment(testEnv),
        throwsA(isA<ConfigError>().having(
          (e) => e.message,
          'message',
          contains('TEST_GEMINI_API_KEY'),
        )),
      );
    });

    test('throws ConfigError when API key is empty', () {
      final testEnv = {
        'TEST_GEMINI_API_KEY': '',
      };

      expect(
        () => GeminiEnvConfig.fromEnvironment(testEnv),
        throwsA(isA<ConfigError>().having(
          (e) => e.message,
          'message',
          contains('TEST_GEMINI_API_KEY'),
        )),
      );
    });

    // Case A4.1: invalid base URL format fails clearly
    test('throws ConfigError when base URL is invalid', () {
      final testEnv = {
        'TEST_GEMINI_API_KEY': 'test-gemini-key-67890',
        'TEST_GEMINI_BASE_URL': 'not-a-valid-url',
      };

      expect(
        () => GeminiEnvConfig.fromEnvironment(testEnv),
        throwsA(isA<ConfigError>().having(
          (e) => e.message,
          'message',
          contains('Invalid TEST_GEMINI_BASE_URL'),
        )),
      );
    });
  });
}
