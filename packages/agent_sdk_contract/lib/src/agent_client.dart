import 'agent_session.dart';
import 'settings_contracts.dart';

/// Factory interface for creating [AgentSession]s.
///
/// The chat app depends on this interface to start and manage agent sessions
/// without coupling to `agent_core` implementation details.
abstract interface class AgentClient {
  /// Creates a new agent session with the provided [settings].
  AgentSession createSession(AgentSettings settings);

  /// Returns whether the client is ready to accept sessions
  /// (e.g., credentials configured, provider reachable).
  Future<bool> isReady();
}
