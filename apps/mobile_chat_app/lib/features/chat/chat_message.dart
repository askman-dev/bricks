/// A chat message displayed in the [MessageList].
///
/// This is a thin view-model for the chat UI, distinct from
/// the [chat_domain] package's `Message` domain model.
class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  final String role;
  final String content;
}
