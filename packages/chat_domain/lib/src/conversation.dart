import 'message.dart';

/// A named sequence of messages between the user and the agent.
class Conversation {
  Conversation({
    required this.id,
    required this.title,
    required this.workspaceId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Message>? messages,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        messages = messages ?? [];

  final String id;
  String title;
  final String workspaceId;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<Message> messages;

  /// Appends a message to this conversation and updates [updatedAt].
  void addMessage(Message message) {
    messages.add(message);
    updatedAt = DateTime.now();
  }

  /// Serialises to a JSON-compatible map.
  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'workspace_id': workspaceId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'messages': messages.map((m) => m.toMap()).toList(),
      };

  /// Deserialises from a JSON-compatible map.
  factory Conversation.fromMap(Map<String, Object?> map) {
    return Conversation(
      id: map['id'] as String,
      title: map['title'] as String,
      workspaceId: map['workspace_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      messages: (map['messages'] as List<Object?>?)
              ?.map((e) => Message.fromMap(e as Map<String, Object?>))
              .toList() ??
          [],
    );
  }
}
