import 'chat_message.dart';

class ChatTaskEnvelope {
  const ChatTaskEnvelope({
    required this.taskId,
    required this.idempotencyKey,
    required this.createdAt,
    required this.channelId,
    required this.sessionId,
    this.threadId,
  });

  final String taskId;
  final String idempotencyKey;
  final DateTime createdAt;
  final String channelId;
  final String sessionId;
  final String? threadId;
}

class ChatTaskAck {
  const ChatTaskAck({
    required this.taskId,
    required this.acceptedAt,
    required this.checkpointCursor,
  });

  final String taskId;
  final DateTime acceptedAt;
  final String checkpointCursor;
}

class ChatSyncCheckpoint {
  const ChatSyncCheckpoint({
    required this.cursor,
    required this.syncedAt,
  });

  final String cursor;
  final DateTime syncedAt;
}

class ChatTaskProtocol {
  ChatTaskAck acknowledge(ChatTaskEnvelope envelope) {
    return ChatTaskAck(
      taskId: envelope.taskId,
      acceptedAt: DateTime.now(),
      checkpointCursor: 'cursor:${envelope.channelId}:${envelope.taskId}',
    );
  }

  ChatSyncCheckpoint nextCheckpoint(ChatTaskAck ack) {
    return ChatSyncCheckpoint(
        cursor: ack.checkpointCursor, syncedAt: DateTime.now());
  }

  ChatMessage applyAcceptedState(ChatMessage message, ChatTaskAck ack) {
    if (message.taskId != ack.taskId) {
      return message;
    }
    return message.copyWith(
      taskState: ChatTaskState.dispatched,
      acknowledgedAt: ack.acceptedAt,
      checkpointCursor: ack.checkpointCursor,
    );
  }
}
