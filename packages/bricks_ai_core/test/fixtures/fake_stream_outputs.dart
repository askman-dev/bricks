import 'package:bricks_ai_core/bricks_ai_core.dart';

/// Returns the canonical event sequence for a plain-text streaming response.
///
/// Expected order:
///   1. [AiTextStartEvent]
///   2. one or more [AiTextDeltaEvent]
///   3. [AiTextEndEvent]
///   4. [AiFinishEvent] with [AiFinishReason.stop]
List<AiStreamEvent> plainTextSequence(String text) => [
      const AiTextStartEvent(),
      AiTextDeltaEvent(text),
      const AiTextEndEvent(),
      const AiFinishEvent(finishReason: AiFinishReason.stop),
    ];

/// Returns the canonical event sequence for a tool-call streaming response.
///
/// Expected order:
///   1. [AiToolCallStartEvent]
///   2. one or more [AiToolCallArgsDeltaEvent]
///   3. [AiToolCallEndEvent]
///   4. [AiFinishEvent] with [AiFinishReason.toolCall]
List<AiStreamEvent> toolCallSequence({
  required String callId,
  required String toolName,
  required String argsJsonDelta,
}) =>
    [
      AiToolCallStartEvent(callId: callId, toolName: toolName),
      AiToolCallArgsDeltaEvent(callId: callId, argsJsonDelta: argsJsonDelta),
      AiToolCallEndEvent(callId: callId),
      const AiFinishEvent(finishReason: AiFinishReason.toolCall),
    ];

/// Returns a multi-chunk text sequence that splits [text] into two deltas.
///
/// Useful for verifying that delta ordering is preserved end-to-end.
List<AiStreamEvent> multiChunkTextSequence(String first, String second) => [
      const AiTextStartEvent(),
      AiTextDeltaEvent(first),
      AiTextDeltaEvent(second),
      const AiTextEndEvent(),
      const AiFinishEvent(finishReason: AiFinishReason.stop),
    ];
