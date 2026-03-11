import 'dart:io';
import 'package:bricks_ai_smoke_test/bricks_ai_smoke_test.dart';
import 'package:test/test.dart';

/// Integration tests for smoke testing AI providers.
///
/// These tests require real API keys to be set in environment variables:
/// - TEST_ANTHROPIC_API_KEY
/// - TEST_GEMINI_API_KEY
///
/// Optional:
/// - TEST_ANTHROPIC_BASE_URL
/// - TEST_GEMINI_BASE_URL
/// - TEST_ANTHROPIC_MODEL
/// - TEST_GEMINI_MODEL
///
/// Tests are skipped if required environment variables are not set.
@Tags(['integration'])
void main() {
  final anthropicKeyPresent =
      Platform.environment['TEST_ANTHROPIC_API_KEY']?.isNotEmpty ?? false;
  final geminiKeyPresent =
      Platform.environment['TEST_GEMINI_API_KEY']?.isNotEmpty ?? false;

  ProviderSmokeResult? anthropicResult;

  group(
    'Anthropic integration tests',
    () {
      setUpAll(() async {
        final runner = ProviderSmokeRunner();
        anthropicResult = await runner.runAnthropicTest();
      });

      // Case B1: Anthropic request returns output
      test(
        'can send request and receive response from Anthropic',
        () async {
          final result = anthropicResult;
          if (result == null) {
            fail('Anthropic result not available');
          }

          expect(result.provider, equals('anthropic'));
          expect(result.success, isTrue,
              reason: 'Failed: ${result.errorMessage}');
          expect(result.statusCode, equals(200));
          expect(result.outputText, isNotNull);
          expect(result.outputText, isNotEmpty);
          expect(result.errorMessage, isNull);

          // Log result for debugging
          print('Anthropic test result: $result');
        },
      );

      // Case B3: Anthropic exact-response check
      test(
        'returns expected text from Anthropic',
        () async {
          final result = anthropicResult;
          if (result == null) {
            fail('Anthropic result not available');
          }

          expect(result.success, isTrue,
              reason: 'Failed: ${result.errorMessage}');

          // Check if response contains or matches expected text (after trim)
          final trimmedOutput = result.outputText?.trim().toLowerCase() ?? '';
          expect(
            trimmedOutput,
            contains('anthropic'),
            reason:
                'Expected response to contain "anthropic", got: $trimmedOutput',
          );

          print('Anthropic response: ${result.outputText}');
        },
      );
    },
    skip: !anthropicKeyPresent ? 'TEST_ANTHROPIC_API_KEY not set' : null,
  );

  ProviderSmokeResult? geminiResult;

  group(
    'Gemini integration tests',
    () {
      setUpAll(() async {
        final runner = ProviderSmokeRunner();
        geminiResult = await runner.runGeminiTest();
      });

      // Case B2: Gemini request returns output
      test(
        'can send request and receive response from Gemini',
        () async {
          final result = geminiResult;
          if (result == null) {
            fail('Gemini result not available');
          }

          expect(result.provider, equals('gemini'));
          expect(result.success, isTrue,
              reason: 'Failed: ${result.errorMessage}');
          expect(result.statusCode, equals(200));
          expect(result.outputText, isNotNull);
          expect(result.outputText, isNotEmpty);
          expect(result.errorMessage, isNull);

          // Log result for debugging
          print('Gemini test result: $result');
        },
      );

      // Case B4: Gemini exact-response check
      test(
        'returns expected text from Gemini',
        () async {
          final result = geminiResult;
          if (result == null) {
            fail('Gemini result not available');
          }

          expect(result.success, isTrue,
              reason: 'Failed: ${result.errorMessage}');

          // Check if response contains or matches expected text (after trim)
          final trimmedOutput = result.outputText?.trim().toLowerCase() ?? '';
          expect(
            trimmedOutput,
            contains('gemini'),
            reason: 'Expected response to contain "gemini", got: $trimmedOutput',
          );

          print('Gemini response: ${result.outputText}');
        },
      );
    },
    skip: !geminiKeyPresent ? 'TEST_GEMINI_API_KEY not set' : null,
  );

  group('ProviderSmokeRunner', () {
    test(
      'can run all providers in parallel',
      () async {
        final runner = ProviderSmokeRunner();
        final results = await runner.runAllTests();

        expect(results, hasLength(2));
        expect(results, contains('anthropic'));
        expect(results, contains('gemini'));

        if (anthropicKeyPresent) {
          expect(results['anthropic']?.success, isTrue,
              reason: 'Anthropic: ${results['anthropic']?.errorMessage}');
        }

        if (geminiKeyPresent) {
          expect(results['gemini']?.success, isTrue,
              reason: 'Gemini: ${results['gemini']?.errorMessage}');
        }

        print('All results: $results');
      },
      skip: !(anthropicKeyPresent || geminiKeyPresent)
          ? 'No API keys set'
          : null,
    );
  });
}
