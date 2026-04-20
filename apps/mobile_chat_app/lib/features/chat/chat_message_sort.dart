import 'chat_message.dart';

/// Compares two [ChatMessage]s by creation time for deterministic ordering.
///
/// Primary sort key (when available from server): immutable `seqId`.
/// Secondary key for synced deltas: `writeSeq` (sync cursor semantics).
/// Fallback key: `createdAt` falling back to `timestamp`.
/// Final tie-breakers: `role` (user before assistant), then `messageId`.
int compareChatMessagesByCreatedTime(ChatMessage a, ChatMessage b) {
  final aSeqId = a.seqId;
  final bSeqId = b.seqId;
  if (aSeqId != null && bSeqId != null) {
    final bySeqId = aSeqId.compareTo(bSeqId);
    if (bySeqId != 0) return bySeqId;
  }

  final aWriteSeq = a.writeSeq;
  final bWriteSeq = b.writeSeq;
  if (aWriteSeq != null && bWriteSeq != null) {
    final byWriteSeq = aWriteSeq.compareTo(bWriteSeq);
    if (byWriteSeq != 0) return byWriteSeq;
  }
  final aTime = a.createdAt ?? a.timestamp;
  final bTime = b.createdAt ?? b.timestamp;
  final byTime = aTime.compareTo(bTime);
  if (byTime != 0) return byTime;
  if (a.role != b.role) {
    if (a.role == 'user') return -1;
    if (b.role == 'user') return 1;
  }
  return (a.messageId ?? '').compareTo(b.messageId ?? '');
}

/// Normalises the task state for a server-provided message.
///
/// If the server explicitly set a task state, that value is returned.
/// Otherwise, a completed assistant message with non-empty content is treated
/// as [ChatTaskState.completed], and [fallback] is returned in all other cases.
ChatTaskState? normalizedServerTaskState(
  ChatMessage message, {
  ChatTaskState? fallback,
}) {
  if (message.taskState != null) return message.taskState;
  if (message.role == 'assistant' && message.content.trim().isNotEmpty) {
    return ChatTaskState.completed;
  }
  return fallback;
}

/// Merges a locally-tracked [current] message with its [incoming] server
/// counterpart, preserving client-side metadata and conversation-position
/// timestamps.
///
/// The local [current.createdAt] and [current.timestamp] are always preferred
/// over the server's values.  For async routers (e.g. OpenClaw) the server
/// assigns `createdAt` at processing / completion time, which can be
/// significantly later than messages the user sent while waiting for the reply.
/// Anchoring to the local (submission) time keeps this message in its correct
/// conversation position after the chronological sort step.
ChatMessage mergeServerMessage(ChatMessage current, ChatMessage incoming) {
  return incoming.copyWith(
    createdAt: current.createdAt,
    timestamp: current.timestamp,
    agentId: incoming.agentId ?? current.agentId,
    agentName: incoming.agentName ?? current.agentName,
    idempotencyKey: current.idempotencyKey,
    acknowledgedAt: incoming.acknowledgedAt ?? current.acknowledgedAt,
    checkpointCursor: incoming.checkpointCursor ?? current.checkpointCursor,
    resolvedBotId: incoming.resolvedBotId ?? current.resolvedBotId,
    resolvedSkillId: incoming.resolvedSkillId ?? current.resolvedSkillId,
    arbitrationMode: current.arbitrationMode,
    fallbackToDefaultBot: current.fallbackToDefaultBot,
    decisionReason: current.decisionReason,
    traceId: current.traceId,
    tieDetected: current.tieDetected,
    tieBotIds: current.tieBotIds,
    selectedScore: current.selectedScore,
    candidateScoreSummary: current.candidateScoreSummary,
    isStreaming: false,
    taskState: normalizedServerTaskState(
      incoming,
      fallback: current.taskState,
    ),
  );
}
