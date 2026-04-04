enum ChatTaskState { accepted, dispatched, completed, failed, cancelled }

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
    this.taskId,
    this.taskState,
    this.channelId,
    this.sessionId,
    this.threadId,
    this.resolvedBotId,
    this.resolvedSkillId,
    this.arbitrationMode = false,
    this.fallbackToDefaultBot = false,
    this.decisionReason,
    this.traceId,
    this.isRecovered = false,
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

  /// Async task metadata for transport lifecycle visibility.
  final String? taskId;
  final ChatTaskState? taskState;
  final String? channelId;
  final String? sessionId;
  final String? threadId;
  final String? resolvedBotId;
  final String? resolvedSkillId;

  /// Arbitration visibility metadata.
  final bool arbitrationMode;
  final bool fallbackToDefaultBot;
  final String? decisionReason;
  final String? traceId;

  /// Whether this message was recovered after reconnect sync.
  final bool isRecovered;

  /// Creates a copy with the given fields replaced.
  ChatMessage copyWith({
    String? role,
    String? content,
    String? agentId,
    String? agentName,
    DateTime? timestamp,
    bool? isStreaming,
    String? taskId,
    ChatTaskState? taskState,
    String? channelId,
    String? sessionId,
    String? threadId,
    String? resolvedBotId,
    String? resolvedSkillId,
    bool? arbitrationMode,
    bool? fallbackToDefaultBot,
    String? decisionReason,
    String? traceId,
    bool? isRecovered,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      agentId: agentId ?? this.agentId,
      agentName: agentName ?? this.agentName,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      taskId: taskId ?? this.taskId,
      taskState: taskState ?? this.taskState,
      channelId: channelId ?? this.channelId,
      sessionId: sessionId ?? this.sessionId,
      threadId: threadId ?? this.threadId,
      resolvedBotId: resolvedBotId ?? this.resolvedBotId,
      resolvedSkillId: resolvedSkillId ?? this.resolvedSkillId,
      arbitrationMode: arbitrationMode ?? this.arbitrationMode,
      fallbackToDefaultBot: fallbackToDefaultBot ?? this.fallbackToDefaultBot,
      decisionReason: decisionReason ?? this.decisionReason,
      traceId: traceId ?? this.traceId,
      isRecovered: isRecovered ?? this.isRecovered,
    );
  }
}
