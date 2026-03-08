/// Manages the context window for an agent session.
///
/// Responsible for accumulating messages, trimming when the token budget is
/// exceeded, and persisting/restoring context across turns.
class ContextManager {
  ContextManager({required this.maxTokens});

  final int maxTokens;
  final List<Map<String, String>> _messages = [];

  List<Map<String, String>> get messages => List.unmodifiable(_messages);

  /// Appends a user turn to the context.
  void addUserMessage(String content) {
    _messages.add({'role': 'user', 'content': content});
    _trimIfNeeded();
  }

  /// Appends an assistant turn to the context.
  void addAssistantMessage(String content) {
    _messages.add({'role': 'assistant', 'content': content});
    _trimIfNeeded();
  }

  /// Clears all messages.
  void clear() => _messages.clear();

  /// Releases any held resources.
  void dispose() => clear();

  void _trimIfNeeded() {
    // TODO(agent_core): implement token counting and context trimming strategy.
  }
}
