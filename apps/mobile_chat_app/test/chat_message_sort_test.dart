import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat_app/features/chat/chat_message.dart';
import 'package:mobile_chat_app/features/chat/chat_message_sort.dart';

void main() {
  group('mergeServerMessage', () {
    test(
      'preserves local createdAt when server async reply has later timestamp',
      () {
        final t20 = DateTime.utc(2026, 4, 19, 12, 0, 20);
        final t35 = DateTime.utc(2026, 4, 19, 12, 0, 35);

        final localPlaceholder = ChatMessage(
          messageId: 'a1',
          role: 'assistant',
          content: '',
          isStreaming: true,
          createdAt: t20,
          taskState: ChatTaskState.accepted,
          channelId: 'default',
          sessionId: 'session:default:main',
        );
        final serverReply = ChatMessage(
          messageId: 'a1',
          role: 'assistant',
          content: 'openclaw async reply',
          createdAt: t35,
          taskState: ChatTaskState.completed,
          channelId: 'default',
          sessionId: 'session:default:main',
        );

        final merged = mergeServerMessage(localPlaceholder, serverReply);

        expect(merged.createdAt, equals(t20));
        expect(merged.timestamp, equals(localPlaceholder.timestamp));
        expect(merged.content, equals('openclaw async reply'));
        expect(merged.taskState, equals(ChatTaskState.completed));
        expect(merged.isStreaming, isFalse);
      },
    );

    test('async reply with preserved createdAt sorts before later messages',
        () {
      final t20 = DateTime.utc(2026, 4, 19, 12, 0, 20);
      final t30 = DateTime.utc(2026, 4, 19, 12, 0, 30);
      final t35 = DateTime.utc(2026, 4, 19, 12, 0, 35);

      final localPlaceholder = ChatMessage(
        messageId: 'a1',
        role: 'assistant',
        content: '',
        createdAt: t20,
        taskState: ChatTaskState.accepted,
      );
      final serverReply = ChatMessage(
        messageId: 'a1',
        role: 'assistant',
        content: 'openclaw async reply',
        createdAt: t35,
        taskState: ChatTaskState.completed,
      );
      final laterUserMsg = ChatMessage(
        messageId: 'u2',
        role: 'user',
        content: 'message sent while waiting',
        createdAt: t30,
      );
      final laterAssistantMsg = ChatMessage(
        messageId: 'a2',
        role: 'assistant',
        content: 'default router reply',
        createdAt: t30,
        taskState: ChatTaskState.completed,
      );

      final mergedReply = mergeServerMessage(localPlaceholder, serverReply);
      final messages = [mergedReply, laterUserMsg, laterAssistantMsg]
        ..sort(compareChatMessagesByCreatedTime);

      expect(messages.first.messageId, equals('a1'));
      expect(messages[1].messageId, equals('u2'));
      expect(messages.last.messageId, equals('a2'));
    });

    test('uses server createdAt when no local createdAt is set', () {
      final tServer = DateTime.utc(2026, 4, 19, 12, 0, 10);

      final local = ChatMessage(
        messageId: 'm1',
        role: 'user',
        content: 'hello',
      );
      final server = ChatMessage(
        messageId: 'm1',
        role: 'user',
        content: 'hello',
        createdAt: tServer,
      );

      final merged = mergeServerMessage(local, server);

      expect(merged.createdAt, equals(tServer));
    });
  });

  group('normalizedServerTaskState', () {
    test('returns explicit taskState from server', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'hi',
        taskState: ChatTaskState.failed,
      );
      expect(normalizedServerTaskState(msg), equals(ChatTaskState.failed));
    });

    test('infers completed for non-empty assistant content with no taskState',
        () {
      final msg = ChatMessage(role: 'assistant', content: 'hi');
      expect(normalizedServerTaskState(msg), equals(ChatTaskState.completed));
    });

    test('returns fallback when no taskState and empty content', () {
      final msg = ChatMessage(role: 'assistant', content: '');
      expect(
        normalizedServerTaskState(msg, fallback: ChatTaskState.dispatched),
        equals(ChatTaskState.dispatched),
      );
    });
  });

  group('compareChatMessagesByCreatedTime', () {
    test('uses seqId as primary key when present on both messages', () {
      final olderBySeqId = ChatMessage(
        messageId: 'msg-user',
        seqId: 89,
        writeSeq: 1754,
        role: 'user',
        content: 'query',
        createdAt: DateTime.utc(2026, 4, 19, 19, 37, 9, 275),
      );
      final newerBySeqIdButOlderWriteSeq = ChatMessage(
        messageId: 'msg-assistant',
        seqId: 90,
        writeSeq: 1750,
        role: 'assistant',
        content: 'reply',
        createdAt: DateTime.utc(2026, 4, 19, 11, 37, 11),
      );

      final sorted = [newerBySeqIdButOlderWriteSeq, olderBySeqId]
        ..sort(compareChatMessagesByCreatedTime);

      expect(sorted.first.messageId, equals('msg-user'));
      expect(sorted.last.messageId, equals('msg-assistant'));
    });

    test('falls back to writeSeq when seqId is absent', () {
      final a = ChatMessage(
        messageId: 'task-1',
        writeSeq: 100,
        role: 'assistant',
        content: 'older',
        createdAt: DateTime.utc(2026, 4, 20, 0, 0, 1),
      );
      final b = ChatMessage(
        messageId: 'task-2',
        writeSeq: 101,
        role: 'assistant',
        content: 'newer',
        createdAt: DateTime.utc(2026, 4, 19, 0, 0, 1),
      );

      final sorted = [b, a]..sort(compareChatMessagesByCreatedTime);

      expect(sorted.first.messageId, equals('task-1'));
      expect(sorted.last.messageId, equals('task-2'));
    });
  });

  group('ChatMessage.fromMap timestamp parsing', () {
    test('parses no-timezone timestamp strings as UTC', () {
      final parsed = ChatMessage.fromMap({
        'role': 'assistant',
        'content': 'ok',
        'createdAt': '2026-04-19 11:37:11',
        'timestamp': '2026-04-19 11:37:11',
      });

      expect(parsed.createdAt, isNotNull);
      expect(parsed.createdAt!.isUtc, isTrue);
      expect(parsed.createdAt, equals(DateTime.utc(2026, 4, 19, 11, 37, 11)));
    });
  });
}
