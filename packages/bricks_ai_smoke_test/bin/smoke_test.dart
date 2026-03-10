import 'package:bricks_ai_smoke_test/bricks_ai_smoke_test.dart';

/// Command-line tool for running AI provider smoke tests.
///
/// Usage:
///   dart run bricks_ai_smoke_test:smoke_test
///
/// Environment variables:
///   TEST_ANTHROPIC_API_KEY (required for Anthropic)
///   TEST_GEMINI_API_KEY (required for Gemini)
///   TEST_ANTHROPIC_BASE_URL (optional)
///   TEST_GEMINI_BASE_URL (optional)
void main() async {
  print('🔍 Running AI Provider Smoke Tests\n');

  final runner = ProviderSmokeRunner();
  final results = await runner.runAllTests();

  var allSuccess = true;

  for (final entry in results.entries) {
    final provider = entry.key;
    final result = entry.value;

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('Provider: $provider');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (result.success) {
      print('✅ Status: SUCCESS');
      print('📊 HTTP Status: ${result.statusCode}');
      print('📝 Output: ${result.outputText?.substring(0, result.outputText!.length > 100 ? 100 : result.outputText!.length)}${(result.outputText?.length ?? 0) > 100 ? '...' : ''}');
    } else {
      print('❌ Status: FAILED');
      if (result.statusCode != null) {
        print('📊 HTTP Status: ${result.statusCode}');
      }
      print('💥 Error: ${result.errorMessage}');
      allSuccess = false;
    }
    print('');
  }

  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  if (allSuccess) {
    print('✅ All smoke tests passed!');
    print('');
    print('✨ The basic request mechanism is working.');
    print('');
  } else {
    print('❌ Some smoke tests failed.');
    print('');
    print('Please check:');
    print('  - Environment variables are set correctly');
    print('  - API keys are valid');
    print('  - Base URLs are accessible');
    print('');
  }
}
