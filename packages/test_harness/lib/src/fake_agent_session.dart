import 'package:agent_sdk_contract/agent_sdk_contract.dart';

/// A fake [AgentSession] that emits a canned response.
class FakeAgentSession implements AgentSession {
  FakeAgentSession({
    required AgentSettings settings,
    this.cannedResponse = 'Fake agent response.',
  }) : sessionId = 'fake-session-${++_counter}';

  @override
  final String sessionId;

  final String cannedResponse;

  bool _running = false;

  @override
  bool get isRunning => _running;

  @override
  Stream<AgentSessionEvent> sendMessage(String message) async* {
    _running = true;
    yield TextDeltaEvent(cannedResponse);
    yield MessageCompleteEvent(cannedResponse);
    yield const RunCompleteEvent();
    _running = false;
  }

  @override
  Future<void> cancel() async {
    _running = false;
  }

  @override
  Future<void> dispose() async {
    _running = false;
  }

  static int _counter = 0;
}
