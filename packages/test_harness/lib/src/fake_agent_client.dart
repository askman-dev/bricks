import 'package:agent_sdk_contract/agent_sdk_contract.dart';
import 'fake_agent_session.dart';

/// A fake [AgentClient] for use in tests.
///
/// Returns [FakeAgentSession]s with configurable canned responses.
class FakeAgentClient implements AgentClient {
  FakeAgentClient({
    this.readyResult = true,
    this.cannedResponse = 'Fake agent response.',
  });

  final bool readyResult;
  final String cannedResponse;

  final List<FakeAgentSession> createdSessions = [];

  @override
  Future<bool> isReady() async => readyResult;

  @override
  AgentSession createSession(AgentSettings settings) {
    final session = FakeAgentSession(
      settings: settings,
      cannedResponse: cannedResponse,
    );
    createdSessions.add(session);
    return session;
  }
}
