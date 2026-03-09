import 'ai_generate_result.dart';
import 'ai_request.dart';
import 'ai_stream_event.dart';

/// Describes the optional capabilities that a model supports.
class AiModelCapabilities {
  const AiModelCapabilities({
    this.supportsStreaming = true,
    this.supportsVision = false,
    this.supportsTools = false,
    this.supportsReasoning = false,
  });

  /// Whether the model supports streaming output via [AiModel.streamGenerate].
  final bool supportsStreaming;

  /// Whether the model accepts image / multimodal inputs.
  final bool supportsVision;

  /// Whether the model can invoke tools / function calls.
  final bool supportsTools;

  /// Whether the model emits chain-of-thought reasoning tokens.
  final bool supportsReasoning;
}

/// A single AI model that can execute inference requests.
///
/// Implementations are created by [AiProvider.model] and must be usable
/// without any knowledge of the underlying vendor SDK.
abstract interface class AiModel {
  /// The provider that created this model (e.g. 'openai', 'anthropic').
  String get providerId;

  /// The vendor model identifier (e.g. 'gpt-4.1-mini', 'claude-sonnet-4-5').
  String get modelId;

  /// Declarative description of what this model supports.
  ///
  /// Callers may read capabilities without starting a request.
  AiModelCapabilities get capabilities;

  /// Runs a single non-streaming inference and returns the full result.
  Future<AiGenerateResult> generate(AiRequest request);

  /// Runs a streaming inference and returns a normalized event stream.
  ///
  /// All providers must normalize their vendor-specific event format into the
  /// [AiStreamEvent] hierarchy.
  Stream<AiStreamEvent> streamGenerate(AiRequest request);
}
