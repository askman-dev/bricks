import 'package:bricks_ai_core/bricks_ai_core.dart';
import 'package:test/test.dart';

import 'fixtures/fake_ai_model.dart';
import 'fixtures/fake_ai_provider.dart';

void main() {
  group('AiProvider contract', () {
    // Case 6.1: provider exposes stable id
    test('provider returns its stable id', () {
      final provider = FakeAiProvider(id: 'anthropic');
      expect(provider.id, equals('anthropic'));
    });

    // Case 6.2: provider can create model by id
    test('model() returns an object implementing AiModel', () {
      final provider = FakeAiProvider(id: 'anthropic');
      final model = provider.model('claude-sonnet-test');
      expect(model, isA<AiModel>());
    });

    // Case 6.3: provider options are accepted at model construction
    test('provider accepts AiProviderOptions without error', () {
      final provider = FakeAiProvider(id: 'anthropic');
      const options = AiProviderOptions(
        baseUrl: 'https://api.example.com',
        apiKey: 'sk-test-key',
        headers: {'X-Custom': 'value'},
      );

      final model = provider.model('claude-sonnet-test', options);

      expect(model, isA<AiModel>());
      // Verify the fake model received the options unchanged.
      expect((model as FakeAiModel).options, same(options));
      expect(provider.lastOptions, same(options));
    });

    // Case 6.4: provider does not leak vendor DTOs into public core contract
    test('provider returns only core abstractions – no vendor types', () {
      // This test verifies that tests compile using only bricks_ai_core imports.
      // No vendor SDK packages (openai, anthropic, etc.) are imported above.
      final provider = FakeAiProvider(id: 'openai');
      final model = provider.model('gpt-4.1-mini');

      // If this compiles and runs, the public API surface is clean.
      expect(model, isA<AiModel>());
      expect(model.providerId, equals('openai'));
      expect(model.modelId, equals('gpt-4.1-mini'));
    });
  });
}
