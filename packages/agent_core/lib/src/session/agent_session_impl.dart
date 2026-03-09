import 'dart:async';
import 'package:agent_sdk_contract/agent_sdk_contract.dart';
import '../context/context_manager.dart';

/// Concrete implementation of [AgentSession].
///
/// Owns the run loop: builds context, calls the provider, executes tools,
/// and emits [AgentSessionEvent]s back to the caller.
class AgentSessionImpl implements AgentSession {
  AgentSessionImpl({required this.settings})
      : sessionId = _generateId(),
        _context = ContextManager(maxTokens: settings.maxContextTokens);

  @override
  final String sessionId;

  final AgentSettings settings;
  final ContextManager _context;

  bool _running = false;
  bool _cancelled = false;
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
    _cancelled = false;

    try {
      _context.addUserMessage(message);

      // Capture cancellation state once before emitting any events, so all
      // emissions in this turn are consistent even if cancel() is called
      // concurrently on the event loop.
      final wasCancelled = _cancelled;
      // TODO(agent_core): integrate with real provider via providers layer.
      // Placeholder: emit a stub response.
      if (!wasCancelled) {
        _controller!.add(const TextDeltaEvent('(agent_core stub) '));
        _controller!.add(TextDeltaEvent('Received: $message'));
        _controller!.add(
          MessageCompleteEvent('(agent_core stub) Received: $message'),
        );
      }
    } catch (e) {
      if (!_cancelled) {
        _controller!.add(AgentErrorEvent(message: e.toString(), isFatal: true));
      }
    } finally {
      _running = false;
      // Emit the terminal event and close the controller exactly once here.
      final ctrl = _controller;
      if (ctrl != null && !ctrl.isClosed) {
        ctrl.add(RunCompleteEvent(cancelled: _cancelled));
        await ctrl.close();
      }
    }
  }

  @override
  Future<void> cancel() async {
    if (!_running) return;
    // Signal _run()'s loop to stop. _run()'s finally block will emit
    // RunCompleteEvent(cancelled: true) and close the controller.
    _cancelled = true;
    _running = false;
  }

  @override
  Future<void> dispose() async {
    await cancel();
    _context.dispose();
  }

  static int _idCounter = 0;
  static String _generateId() => 'session-${++_idCounter}';
}
