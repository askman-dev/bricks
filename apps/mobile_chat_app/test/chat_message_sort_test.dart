import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat_app/features/chat/chat_message.dart';
import 'package:mobile_chat_app/features/chat/chat_message_sort.dart';

void main() {
  group('mergeServerMessage', () {
    test(
      'preserves local createdAt when server async reply has later timestamp',
      () {
        // Simulate OpenClaw async scenario:
        //   - User sends message M1 at T=20 and assistant placeholder is
        //     created at the same task-submission time.
        //   - After routing switch the user sends M2 at T=30 and gets an
        //     immediate reply.
        //   - OpenClaw completes and the server stores the assistant reply with
        //     createdAt = T=35 (completion time).
        //   - Without the fix, mergeServerMessage would adopt T=35, causing the
        //     sort to place the OpenClaw reply AFTER M2/A2 (T=30) in the list.
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

        // createdAt must be the local (submission) time, not completion time.
        expect(merged.createdAt, equals(t20));
        // timestamp must also be preserved for the display clock in MessageList.
        expect(merged.timestamp, equals(localPlaceholder.timestamp));
        // Content and task state come from the server.
        expect(merged.content, equals('openclaw async reply'));
        expect(merged.taskState, equals(ChatTaskState.completed));
        expect(merged.isStreaming, isFalse);
      },
    );

    test(
      'async reply with preserved createdAt sorts before later messages',
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
          createdAt: t35, // server completion time > messages sent later
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

        // openClaw reply (originally T=20) must come before messages at T=30.
        expect(messages.first.messageId, equals('a1'));
        expect(messages[1].messageId, equals('u2'));
        expect(messages.last.messageId, equals('a2'));
      },
    );

    test('uses server createdAt when no local createdAt is set', () {
      final tServer = DateTime.utc(2026, 4, 19, 12, 0, 10);

      final local = ChatMessage(
        messageId: 'm1',
        role: 'user',
        content: 'hello',
        // createdAt intentionally omitted
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
}
