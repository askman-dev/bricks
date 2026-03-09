import 'package:agent_sdk_contract/agent_sdk_contract.dart';
import '../session/agent_session_impl.dart';

/// Concrete implementation of [AgentClient].
///
/// Creates and manages [AgentSession]s backed by the real agent run loop.
class AgentCoreClient implements AgentClient {
  AgentCoreClient();

  @override
  AgentSession createSession(AgentSettings settings) {
    return AgentSessionImpl(settings: settings);
  }

  @override
  Future<bool> isReady() async {
    // TODO(agent_core): check provider credentials and reachability.
    return true;
  }
}
