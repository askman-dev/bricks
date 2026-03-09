/// A single message in an AI conversation turn.
class AiMessage {
  const AiMessage({required this.role, required this.content});

  /// The role of the message author: 'user', 'assistant', 'system', or 'tool'.
  final String role;

  /// The text content of this message.
  final String content;
}
