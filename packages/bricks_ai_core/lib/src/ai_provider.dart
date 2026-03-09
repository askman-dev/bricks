import 'ai_model.dart';
import 'ai_provider_options.dart';

/// Factory interface for a single AI provider (e.g. OpenAI, Anthropic, Gemini).
///
/// Business code depends on this interface; concrete implementations live in
/// separate packages and are never imported by callers.
abstract interface class AiProvider {
  /// Stable identifier for this provider (e.g. 'openai', 'anthropic').
  ///
  /// IDs must be lowercase ASCII and use underscores for multi-word names
  /// (e.g. 'vertex_ai'). The value must remain constant for the lifetime of
  /// the provider instance.
  String get id;

  /// Creates an [AiModel] for the given [modelId].
  ///
  /// Optional [options] allow callers to pass API keys, base URLs, and
  /// provider-specific configuration at construction time.
  AiModel model(String modelId, [AiProviderOptions? options]);
}
