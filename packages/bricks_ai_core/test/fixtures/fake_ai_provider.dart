import 'package:bricks_ai_core/bricks_ai_core.dart';

import 'fake_ai_model.dart';

/// A minimal [AiProvider] implementation for contract tests.
///
/// Stores the provider ID and creates [FakeAiModel] instances.
class FakeAiProvider implements AiProvider {
  FakeAiProvider({required this.id});

  @override
  final String id;

  /// The options most recently passed to [model], if any.
  AiProviderOptions? lastOptions;

  @override
  AiModel model(String modelId, [AiProviderOptions? options]) {
    lastOptions = options;
    return FakeAiModel(
      providerId: id,
      modelId: modelId,
      options: options,
    );
  }
}
