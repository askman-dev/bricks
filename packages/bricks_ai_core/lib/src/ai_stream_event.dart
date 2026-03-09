import 'ai_generate_result.dart';

/// A structured error emitted during AI stream generation.
class AiStructuredError {
  const AiStructuredError({
    required this.code,
    required this.message,
    this.details,
  });

  /// A short machine-readable error code (e.g. 'rate_limit', 'auth_error').
  final String code;

  /// A human-readable description of the error.
  final String message;

  /// Optional provider-specific error details.
  final Object? details;
}

/// Base class for all events emitted by [AiModel.streamGenerate].
///
/// Concrete providers must normalize their vendor-specific streaming protocol
/// into this unified event hierarchy.
sealed class AiStreamEvent {
  const AiStreamEvent();
}

/// Signals that a new text block has started.
final class AiTextStartEvent extends AiStreamEvent {
  const AiTextStartEvent();
}

/// A chunk of text within the current text block.
final class AiTextDeltaEvent extends AiStreamEvent {
  const AiTextDeltaEvent(this.textDelta);

  final String textDelta;
}

/// Signals that the current text block has ended.
final class AiTextEndEvent extends AiStreamEvent {
  const AiTextEndEvent();
}

/// A chunk of reasoning / chain-of-thought text emitted before the answer.
final class AiReasoningDeltaEvent extends AiStreamEvent {
  const AiReasoningDeltaEvent(this.textDelta);

  final String textDelta;
}

/// Signals that the model is starting a tool call.
final class AiToolCallStartEvent extends AiStreamEvent {
  const AiToolCallStartEvent({required this.callId, required this.toolName});

  /// Stable identifier for this tool call within the response.
  final String callId;

  /// The name of the tool to invoke.
  final String toolName;
}

/// A fragment of the tool-call arguments JSON.
///
/// Fragments must be concatenated in emission order to produce the full JSON.
final class AiToolCallArgsDeltaEvent extends AiStreamEvent {
  const AiToolCallArgsDeltaEvent({
    required this.callId,
    required this.argsJsonDelta,
  });

  /// The tool call this fragment belongs to.
  final String callId;

  /// The raw JSON fragment (may be an incomplete JSON substring).
  final String argsJsonDelta;
}

/// Signals that a tool call's arguments have been fully streamed.
final class AiToolCallEndEvent extends AiStreamEvent {
  const AiToolCallEndEvent({required this.callId});

  final String callId;
}

/// Reports token usage, if available before the finish event.
final class AiUsageEvent extends AiStreamEvent {
  const AiUsageEvent(this.usage);

  final AiUsage usage;
}

/// Signals that the stream has finished normally.
final class AiFinishEvent extends AiStreamEvent {
  const AiFinishEvent({required this.finishReason});

  final AiFinishReason finishReason;
}

/// Signals that the stream terminated with an error.
final class AiErrorEvent extends AiStreamEvent {
  const AiErrorEvent({required this.error});

  final AiStructuredError error;
}
