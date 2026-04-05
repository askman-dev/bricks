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
    this.idempotencyKey,
    this.createdAt,
    this.acknowledgedAt,
    this.checkpointCursor,
    this.channelId,
    this.sessionId,
    this.threadId,
    this.resolvedBotId,
    this.resolvedSkillId,
    this.arbitrationMode = false,
    this.fallbackToDefaultBot = false,
    this.decisionReason,
    this.traceId,
    this.tieDetected = false,
    this.tieBotIds = const [],
    this.selectedScore,
    this.candidateScoreSummary,
    this.isRecovered = false,
  }) : timestamp = timestamp ?? DateTime.now();

  final String role;
  final String content;

  final String? agentId;
  final String? agentName;
  final DateTime timestamp;
  final bool isStreaming;

  final String? taskId;
  final ChatTaskState? taskState;
  final String? idempotencyKey;
  final DateTime? createdAt;
  final DateTime? acknowledgedAt;
  final String? checkpointCursor;

  final String? channelId;
  final String? sessionId;
  final String? threadId;
  final String? resolvedBotId;
  final String? resolvedSkillId;

  final bool arbitrationMode;
  final bool fallbackToDefaultBot;
  final String? decisionReason;
  final String? traceId;
  final bool tieDetected;
  final List<String> tieBotIds;
  final double? selectedScore;
  final String? candidateScoreSummary;

  final bool isRecovered;

  ChatMessage copyWith({
    String? role,
    String? content,
    String? agentId,
    String? agentName,
    DateTime? timestamp,
    bool? isStreaming,
    String? taskId,
    ChatTaskState? taskState,
    String? idempotencyKey,
    DateTime? createdAt,
    DateTime? acknowledgedAt,
    String? checkpointCursor,
    String? channelId,
    String? sessionId,
    String? threadId,
    String? resolvedBotId,
    String? resolvedSkillId,
    bool? arbitrationMode,
    bool? fallbackToDefaultBot,
    String? decisionReason,
    String? traceId,
    bool? tieDetected,
    List<String>? tieBotIds,
    double? selectedScore,
    String? candidateScoreSummary,
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
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      createdAt: createdAt ?? this.createdAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      checkpointCursor: checkpointCursor ?? this.checkpointCursor,
      channelId: channelId ?? this.channelId,
      sessionId: sessionId ?? this.sessionId,
      threadId: threadId ?? this.threadId,
      resolvedBotId: resolvedBotId ?? this.resolvedBotId,
      resolvedSkillId: resolvedSkillId ?? this.resolvedSkillId,
      arbitrationMode: arbitrationMode ?? this.arbitrationMode,
      fallbackToDefaultBot: fallbackToDefaultBot ?? this.fallbackToDefaultBot,
      decisionReason: decisionReason ?? this.decisionReason,
      traceId: traceId ?? this.traceId,
      tieDetected: tieDetected ?? this.tieDetected,
      tieBotIds: tieBotIds ?? this.tieBotIds,
      selectedScore: selectedScore ?? this.selectedScore,
      candidateScoreSummary:
          candidateScoreSummary ?? this.candidateScoreSummary,
      isRecovered: isRecovered ?? this.isRecovered,
    );
  }
}
