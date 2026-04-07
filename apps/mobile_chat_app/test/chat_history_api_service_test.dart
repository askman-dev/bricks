import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_chat_app/features/chat/chat_history_api_service.dart';
import 'package:mobile_chat_app/features/chat/chat_message.dart';
import 'package:mobile_chat_app/features/chat/chat_topology.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads history snapshot from backend response', () async {
    final client = MockClient((request) async {
      expect(request.method, equals('GET'));
      return http.Response(
        jsonEncode({
          'messages': [
            {
              'messageId': 'm1',
              'role': 'user',
              'content': 'hello',
              'sessionId': 'session:default:main',
              'channelId': 'default',
            },
            {
              'messageId': 'm2',
              'role': 'assistant',
              'content': 'hi',
              'taskState': 'completed',
              'sessionId': 'session:default:main',
              'channelId': 'default',
            },
          ],
          'latestCheckpointCursor': 'seq:2',
          'lastSeqId': 2,
        }),
        200,
      );
    });

    final service = ChatHistoryApiService(httpClient: client);
    final snapshot = await service.load(
      token: 'token-1',
      sessionId: 'session:default:main',
    );

    expect(snapshot.messages, hasLength(2));
    expect(snapshot.messages.last.taskState, ChatTaskState.completed);
    expect(snapshot.latestCheckpointCursor, equals('seq:2'));
    expect(snapshot.lastSeqId, equals(2));
  });

  test('accepts task and upserts messages', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/tasks/accept')) {
        expect(request.method, equals('POST'));
        return http.Response(
          jsonEncode({
            'taskId': 'task-1',
            'sessionId': 'session:default:main',
            'state': 'accepted',
            'acceptedAt': '2026-04-07T06:00:00.000Z',
          }),
          200,
        );
      }

      expect(request.url.path.endsWith('/messages/batch'), isTrue);
      expect(request.method, equals('PUT'));
      final decoded = jsonDecode(request.body) as Map<String, dynamic>;
      expect((decoded['messages'] as List).length, equals(1));
      return http.Response(jsonEncode({'lastSeqId': 7}), 200);
    });

    final service = ChatHistoryApiService(httpClient: client);
    final accepted = await service.acceptTask(
      token: 'token-1',
      taskId: 'task-1',
      idempotencyKey: 'idem-1',
      scope: const ChatSessionScope(channelId: 'default', threadId: 'main'),
    );
    final lastSeq = await service.upsertMessages(
      token: 'token-1',
      messages: [
        ChatMessage(
          messageId: 'msg-1',
          role: 'user',
          content: 'persist me',
          channelId: 'default',
          sessionId: 'session:default:main',
        ),
      ],
    );

    expect(accepted.taskId, equals('task-1'));
    expect(lastSeq, equals(7));
  });
}
