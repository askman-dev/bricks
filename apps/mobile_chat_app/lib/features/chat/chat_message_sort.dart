import 'chat_message.dart';

/// Compares two [ChatMessage]s by creation time for deterministic ordering.
///
/// Primary sort key: `createdAt` falling back to `timestamp`.
/// Tie-breakers (in order): `role` (user before assistant) then `messageId`.
int compareChatMessagesByCreatedTime(ChatMessage a, ChatMessage b) {
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
