import 'ai_model.dart';

/// A registry that maps qualified model IDs to [AiModel] instances.
///
/// Qualified IDs follow the pattern `<providerId>:<modelId>` (e.g.
/// `openai:gpt-4.1-mini`). Business code resolves models through the
/// registry so that it never constructs provider-specific objects directly.
class AiModelRegistry {
  final Map<String, AiModel> _models = {};

  /// Registers [model] under the given [id].
  ///
  /// If [id] is already registered the previous entry is silently replaced.
  /// Use a qualified format `<providerId>:<modelId>` (e.g.
  /// `openai:gpt-4.1-mini`) to avoid collisions between providers.
  void register(String id, AiModel model) {
    _models[id] = model;
  }

  /// Returns the model registered under [id].
  ///
  /// Throws [StateError] if [id] is not registered.
  AiModel resolve(String id) {
    final model = _models[id];
    if (model == null) {
      throw StateError('Model "$id" is not registered in the registry.');
    }
    return model;
  }
}
