import 'attachments.dart';

/// The role of a message author.
enum MessageRole { user, assistant, system }

/// A single message in a [Conversation].
class Message {
  Message({
    required this.id,
    required this.role,
    required this.content,
    this.agentId,
    this.agentName,
    DateTime? createdAt,
    List<Attachment>? attachments,
  })  : createdAt = createdAt ?? DateTime.now(),
        attachments = attachments ?? [];

  final String id;
  final MessageRole role;
  String content;
  final DateTime createdAt;
  final List<Attachment> attachments;

  /// Identifier of the agent that produced this message.
  ///
  /// Corresponds to [AgentParticipant.agentId] from issue #24.
  /// `null` for user messages or messages without agent attribution.
  final String? agentId;

  /// Display name of the agent that produced this message.
  ///
  /// `null` for user messages or messages without agent attribution.
  final String? agentName;

  Map<String, Object?> toMap() => {
        'id': id,
        'role': role.name,
        'content': content,
        'created_at': createdAt.toIso8601String(),
        'attachments': attachments.map((a) => a.toMap()).toList(),
        if (agentId != null) 'agent_id': agentId,
        if (agentName != null) 'agent_name': agentName,
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
      agentId: map['agent_id'] as String?,
      agentName: map['agent_name'] as String?,
    );
  }
}
