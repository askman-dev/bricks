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

    test(
      'user message with writeSeq sorts before AI reply with higher writeSeq '
      'even when server createdAt is earlier than client local time',
      () {
        // Scenario: openclaw async route. Client sends at local time T1 (later
        // than server clock). respond() returns lastSeqId=50, which is stamped
        // onto the user message as writeSeq. OpenClaw replies with writeSeq=51.
        final clientLocalTime = DateTime.utc(2026, 4, 24, 3, 14, 30); // T1 local
        final serverTime = DateTime.utc(2026, 4, 24, 3, 14, 20); // server 10s behind

        final userMsg = ChatMessage(
          messageId: 'u-local',
          role: 'user',
          content: 'hello',
          // seqId not yet set (user message not re-delivered via SSE)
          writeSeq: 50, // stamped from result.lastSeqId in respond callback
          createdAt: clientLocalTime,
        );
        final aiReply = ChatMessage(
          messageId: 'a-openclaw',
          role: 'assistant',
          content: 'reply',
          seqId: 88,
          writeSeq: 51, // higher than user message
          createdAt: serverTime, // earlier than client local time
        );

        final sorted = [aiReply, userMsg]..sort(compareChatMessagesByCreatedTime);

        expect(sorted.first.messageId, equals('u-local'),
            reason: 'User message should sort before AI reply');
        expect(sorted.last.messageId, equals('a-openclaw'));
      },
    );
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

    test('parses model field from map', () {
      final parsed = ChatMessage.fromMap({
        'role': 'assistant',
        'content': 'hello',
        'model': 'claude-sonnet-4-5',
      });

      expect(parsed.model, equals('claude-sonnet-4-5'));
    });
  });

  group('mergeServerMessage model preservation', () {
    test('incoming model overrides null local model', () {
      final local = ChatMessage(
        messageId: 'm1',
        role: 'assistant',
        content: '',
        isStreaming: true,
      );
      final server = ChatMessage(
        messageId: 'm1',
        role: 'assistant',
        content: 'reply',
        model: 'claude-sonnet-4-5',
        taskState: ChatTaskState.completed,
      );

      final merged = mergeServerMessage(local, server);
      expect(merged.model, equals('claude-sonnet-4-5'));
    });

    test('local model is preserved when server sends null model', () {
      final local = ChatMessage(
        messageId: 'm1',
        role: 'assistant',
        content: '',
        model: 'gpt-4o',
        isStreaming: true,
      );
      final server = ChatMessage(
        messageId: 'm1',
        role: 'assistant',
        content: 'reply',
        taskState: ChatTaskState.completed,
      );

      final merged = mergeServerMessage(local, server);
      expect(merged.model, equals('gpt-4o'));
    });
  });
}
