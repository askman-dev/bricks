/// A chat message displayed in the [MessageList].
///
/// This is a thin view-model for the chat UI, distinct from
/// the [chat_domain] package's `Message` domain model.
class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    this.agentId,
    this.agentName,
  });

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
}
