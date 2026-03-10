import 'anthropic_smoke_client.dart';
import 'gemini_smoke_client.dart';
import 'provider_env_config.dart';
import 'smoke_result.dart';

/// Orchestrates smoke tests for AI providers.
class ProviderSmokeRunner {
  /// Run smoke test for Anthropic provider.
  ///
  /// Loads configuration from environment and sends a test request.
  /// Returns [ProviderSmokeResult] with success status.
  Future<ProviderSmokeResult> runAnthropicTest({
    String prompt = 'Reply with exactly: anthropic-ok',
  }) async {
    try {
      final config = AnthropicEnvConfig.fromEnvironment();
      final client = AnthropicSmokeClient(config);
      try {
        return await client.sendTestRequest(prompt: prompt);
      } finally {
        client.dispose();
      }
    } on ConfigError catch (e) {
      return ProviderSmokeResult(
        provider: 'anthropic',
        success: false,
        errorMessage: e.message,
      );
    } catch (e) {
      return ProviderSmokeResult(
        provider: 'anthropic',
        success: false,
        errorMessage: 'Unexpected error: $e',
      );
    }
  }

  /// Run smoke test for Gemini provider.
  ///
  /// Loads configuration from environment and sends a test request.
  /// Returns [ProviderSmokeResult] with success status.
  Future<ProviderSmokeResult> runGeminiTest({
    String prompt = 'Reply with exactly: gemini-ok',
  }) async {
    try {
      final config = GeminiEnvConfig.fromEnvironment();
      final client = GeminiSmokeClient(config);
      try {
        return await client.sendTestRequest(prompt: prompt);
      } finally {
        client.dispose();
      }
    } on ConfigError catch (e) {
      return ProviderSmokeResult(
        provider: 'gemini',
        success: false,
        errorMessage: e.message,
      );
    } catch (e) {
      return ProviderSmokeResult(
        provider: 'gemini',
        success: false,
        errorMessage: 'Unexpected error: $e',
      );
    }
  }

  /// Run smoke tests for all configured providers.
  ///
  /// Returns a map of provider names to their smoke test results.
  Future<Map<String, ProviderSmokeResult>> runAllTests() async {
    final results = <String, ProviderSmokeResult>{};

    // Run tests in parallel for efficiency
    final anthropicFuture = runAnthropicTest();
    final geminiFuture = runGeminiTest();

    results['anthropic'] = await anthropicFuture;
    results['gemini'] = await geminiFuture;

    return results;
  }
}
