/// Base class for all events emitted by an [AgentSession].
sealed class AgentSessionEvent {
  const AgentSessionEvent();
}

/// A delta of text produced by the model (streaming text chunk).
final class TextDeltaEvent extends AgentSessionEvent {
  const TextDeltaEvent(this.delta);
  final String delta;
}

/// The model has finished producing a complete message turn.
final class MessageCompleteEvent extends AgentSessionEvent {
  const MessageCompleteEvent(this.fullText);
  final String fullText;
}

/// The agent is about to execute a tool call.
final class ToolCallStartEvent extends AgentSessionEvent {
  const ToolCallStartEvent({
    required this.callId,
    required this.toolName,
    required this.arguments,
  });
  final String callId;
  final String toolName;
  final Map<String, Object?> arguments;
}

/// A tool call has completed.
final class ToolCallCompleteEvent extends AgentSessionEvent {
  const ToolCallCompleteEvent({
    required this.callId,
    required this.toolName,
    required this.result,
  });
  final String callId;
  final String toolName;
  final Object? result;
}

/// The agent has delegated work to a sub-agent.
final class SubAgentDelegatedEvent extends AgentSessionEvent {
  const SubAgentDelegatedEvent({
    required this.subAgentId,
    required this.subAgentName,
  });
  final String subAgentId;
  final String subAgentName;
}

/// An error occurred during the agent run.
final class AgentErrorEvent extends AgentSessionEvent {
  const AgentErrorEvent({required this.message, this.isFatal = false});
  final String message;
  final bool isFatal;
}

/// The agent run has completed (successfully or after cancellation).
final class RunCompleteEvent extends AgentSessionEvent {
  const RunCompleteEvent({this.cancelled = false});
  final bool cancelled;
}
