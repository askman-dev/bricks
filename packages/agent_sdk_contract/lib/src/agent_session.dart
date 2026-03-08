import 'event_stream.dart';

/// Represents a live agent conversation session.
///
/// Callers send messages and receive back a stream of [AgentSessionEvent]s
/// that reflect the agent's progress (text deltas, tool calls, errors, etc.).
abstract interface class AgentSession {
  /// The unique identifier for this session.
  String get sessionId;

  /// Whether the session is currently processing a request.
  bool get isRunning;

  /// Sends a user message and returns a stream of events produced by the agent.
  Stream<AgentSessionEvent> sendMessage(String message);

  /// Cancels the current agent run, if one is in progress.
  Future<void> cancel();

  /// Disposes resources held by this session.
  Future<void> dispose();
}
