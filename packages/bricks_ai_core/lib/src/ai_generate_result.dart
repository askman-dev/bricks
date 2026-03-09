/// Why the model stopped generating tokens.
enum AiFinishReason {
  /// The model reached a natural stopping point.
  stop,

  /// The model hit the maximum output token limit.
  maxTokens,

  /// The model stopped to invoke one or more tools.
  toolCall,

  /// The model stopped due to an error condition.
  error,

  /// Generation was cancelled by the caller.
  cancelled,
}

/// Token consumption for a single inference request.
class AiUsage {
  const AiUsage({
    required this.inputTokens,
    required this.outputTokens,
    this.totalTokens,
  });

  /// Number of tokens in the prompt / input.
  final int inputTokens;

  /// Number of tokens generated in the response.
  final int outputTokens;

  /// Pre-computed total, if the provider supplies it. May be null.
  final int? totalTokens;
}

/// A block of output content produced by the model.
///
/// Multiple blocks may appear in a single [AiGenerateResult] when the model
/// emits mixed text and tool calls in the same response.
sealed class AiOutputBlock {
  const AiOutputBlock();
}

/// A block of plain text produced by the model.
final class AiTextBlock extends AiOutputBlock {
  const AiTextBlock(this.text);

  final String text;
}

/// A tool call requested by the model.
final class AiToolCallBlock extends AiOutputBlock {
  const AiToolCallBlock({
    required this.callId,
    required this.toolName,
    required this.argsJson,
  });

  /// Stable identifier for this call within the response.
  final String callId;

  /// The name of the tool to invoke.
  final String toolName;

  /// Raw JSON string of the tool arguments.
  final String argsJson;
}

/// The result of a non-streaming [AiModel.generate] call.
///
/// [output] and [metadata] are stored as unmodifiable views to prevent
/// post-return mutation from affecting caches, logs, or retry logic.
class AiGenerateResult {
  AiGenerateResult({
    required List<AiOutputBlock> output,
    required this.finishReason,
    this.usage,
    Map<String, Object?> metadata = const {},
    this.rawResponse,
  })  : output = List.unmodifiable(output),
        metadata = Map.unmodifiable(metadata);

  /// The list of output blocks produced by the model, in emission order.
  final List<AiOutputBlock> output;

  /// The reason generation stopped.
  final AiFinishReason finishReason;

  /// Token usage for this request, if reported by the provider.
  final AiUsage? usage;

  /// Caller-supplied or provider-attached metadata, passed through unchanged.
  final Map<String, Object?> metadata;

  /// The raw provider response DTO for provider-specific access.
  ///
  /// The core layer stores this without inspection. Callers that need
  /// provider-specific fields can cast this to the known vendor type.
  final Object? rawResponse;
}
