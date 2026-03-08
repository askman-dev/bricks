import 'dart:async';
import 'package:agent_sdk_contract/agent_sdk_contract.dart';
import '../context/context_manager.dart';
import '../tools/tool_executor.dart';

/// Concrete implementation of [AgentSession].
///
/// Owns the run loop: builds context, calls the provider, executes tools,
/// and emits [AgentSessionEvent]s back to the caller.
class AgentSessionImpl implements AgentSession {
  AgentSessionImpl({required this.settings})
      : sessionId = _generateId(),
        _context = ContextManager(maxTokens: settings.maxContextTokens),
        _toolExecutor = ToolExecutor();

  @override
  final String sessionId;

  final AgentSettings settings;
  final ContextManager _context;
  final ToolExecutor _toolExecutor;

  bool _running = false;
  StreamController<AgentSessionEvent>? _controller;

  @override
  bool get isRunning => _running;

  @override
  Stream<AgentSessionEvent> sendMessage(String message) {
    if (_running) {
      throw StateError('Session $sessionId is already running.');
    }

    _controller = StreamController<AgentSessionEvent>();
    _run(message);
    return _controller!.stream;
  }

  Future<void> _run(String message) async {
    _running = true;

    try {
      _context.addUserMessage(message);

      // TODO(agent_core): integrate with real provider via providers layer.
      // Placeholder: emit a stub response.
      _controller!.add(const TextDeltaEvent('(agent_core stub) '));
      _controller!.add(TextDeltaEvent('Received: $message'));
      _controller!.add(MessageCompleteEvent('(agent_core stub) Received: $message'));
      _controller!.add(const RunCompleteEvent());
    } catch (e) {
      _controller!.add(AgentErrorEvent(message: e.toString(), isFatal: true));
    } finally {
      _running = false;
      await _controller!.close();
    }
  }

  @override
  Future<void> cancel() async {
    if (!_running) return;
    _controller?.add(const RunCompleteEvent(cancelled: true));
    _running = false;
    await _controller?.close();
  }

  @override
  Future<void> dispose() async {
    await cancel();
    _context.dispose();
  }

  static int _idCounter = 0;
  static String _generateId() => 'session-${++_idCounter}';
}
