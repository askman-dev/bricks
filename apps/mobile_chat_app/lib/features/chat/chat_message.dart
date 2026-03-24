/// A chat message displayed in the [MessageList].
///
/// This is a thin view-model for the chat UI, distinct from
/// the [chat_domain] package's `Message` domain model.
class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    this.agentId,
    this.agentName,
    DateTime? timestamp,
    this.isStreaming = false,
  }) : timestamp = timestamp ?? DateTime.now();

  final String role;
  final String content;

  /// Identifier of the agent that produced this message.
  ///
  /// `null` for user messages or messages without agent attribution.
  final String? agentId;

  /// Display name of the agent that produced this message.
  ///
  /// `null` for user messages or messages without agent attribution.
  final String? agentName;

  /// When this message was created.
  final DateTime timestamp;

  /// Whether this message is currently being streamed.
  final bool isStreaming;

  /// Creates a copy with the given fields replaced.
  ChatMessage copyWith({
    String? role,
    String? content,
    String? agentId,
    String? agentName,
    DateTime? timestamp,
    bool? isStreaming,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      agentId: agentId ?? this.agentId,
      agentName: agentName ?? this.agentName,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}
