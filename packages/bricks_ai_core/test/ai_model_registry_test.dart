import 'package:bricks_ai_core/bricks_ai_core.dart';
import 'package:test/test.dart';

import 'fixtures/fake_ai_model.dart';

void main() {
  group('AiModelRegistry', () {
    late AiModelRegistry registry;

    setUp(() => registry = AiModelRegistry());

    // Case 4.1: resolves known qualified model id
    test('resolves a registered qualified model id', () {
      final model = FakeAiModel(
        providerId: 'openai',
        modelId: 'gpt-4.1-mini',
      );
      registry.register('openai:gpt-4.1-mini', model);

      final resolved = registry.resolve('openai:gpt-4.1-mini');
      expect(resolved, isA<AiModel>());
    });

    // Case 4.2: throws on unknown model id
    test('throws StateError for an unregistered model id', () {
      expect(
        () => registry.resolve('unknown:model'),
        throwsA(isA<StateError>()),
      );
    });

    // Case 4.3: preserves returned model identity
    test('returns the same registered instance on repeated resolves', () {
      final model = FakeAiModel(
        providerId: 'openai',
        modelId: 'gpt-4.1-mini',
      );
      registry.register('openai:gpt-4.1-mini', model);

      final first = registry.resolve('openai:gpt-4.1-mini');
      final second = registry.resolve('openai:gpt-4.1-mini');

      expect(first, same(second));
      expect(first, same(model));
    });

    // Case 4.4: alias support placeholder
    test(
      'TODO: alias resolution – resolve an alias to the canonical model',
      () {
        // Intended future behavior:
        //   registry.registerAlias('gpt-4-mini', 'openai:gpt-4.1-mini');
        //   expect(registry.resolve('gpt-4-mini'), same(canonicalModel));
        //
        // Alias support is not implemented yet. This test is skipped until
        // the alias feature is added to AiModelRegistry.
      },
      skip: 'Alias resolution not yet implemented – tracked as future work.',
    );
  });
}
