import 'attachments.dart';

/// The role of a message author.
enum MessageRole { user, assistant, system }

/// A single message in a [Conversation].
class Message {
  Message({
    required this.id,
    required this.role,
    required this.content,
    DateTime? createdAt,
    List<Attachment>? attachments,
  })  : createdAt = createdAt ?? DateTime.now(),
        attachments = attachments ?? [];

  final String id;
  final MessageRole role;
  String content;
  final DateTime createdAt;
  final List<Attachment> attachments;

  Map<String, Object?> toMap() => {
        'id': id,
        'role': role.name,
        'content': content,
        'created_at': createdAt.toIso8601String(),
        'attachments': attachments.map((a) => a.toMap()).toList(),
      };

  factory Message.fromMap(Map<String, Object?> map) {
    return Message(
      id: map['id'] as String,
      role: MessageRole.values.byName(map['role'] as String),
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      attachments: (map['attachments'] as List<Object?>?)
              ?.map((e) => Attachment.fromMap(e as Map<String, Object?>))
              .toList() ??
          [],
    );
  }
}
