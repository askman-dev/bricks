import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_chat_app/features/chat/chat_history_api_service.dart';
import 'package:mobile_chat_app/features/chat/chat_message.dart';
import 'package:mobile_chat_app/features/chat/chat_topology.dart';

/// A minimal [http.BaseClient] whose [send] method is fully injectable for
/// testing streaming (SSE) responses that [MockClient] cannot model.
class _MockStreamedClient extends http.BaseClient {
  _MockStreamedClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _handler(request);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads history snapshot from backend response', () async {
    final client = MockClient((request) async {
      expect(request.method, equals('GET'));
      expect(request.url.queryParameters['limit'], equals('100'));
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

  test('sorts loaded history by createdAt to keep chronology stable', () async {
    final client = MockClient((request) async {
      expect(request.method, equals('GET'));
      return http.Response(
        jsonEncode({
          'messages': [
            {
              'messageId': 'assistant-late',
              'role': 'assistant',
              'content': 'openclaw delayed reply',
              'createdAt': '2026-04-19T11:38:15.000Z',
            },
            {
              'messageId': 'user-earlier',
              'role': 'user',
              'content': 'return to default route',
              'createdAt': '2026-04-19T11:38:10.000Z',
            },
          ],
          'lastSeqId': 9,
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
    expect(snapshot.messages.first.messageId, equals('user-earlier'));
    expect(snapshot.messages.last.messageId, equals('assistant-late'));
  });

  test('sorts synced messages by createdAt to keep chronology stable',
      () async {
    final client = MockClient((request) async {
      expect(request.method, equals('GET'));
      expect(request.url.path, contains('/chat/sync/'));
      expect(request.url.queryParameters['afterSeq'], equals('10'));
      expect(request.url.queryParameters.containsKey('waitMs'), isFalse);
      return http.Response(
        jsonEncode({
          'messages': [
            {
              'messageId': 'assistant-async',
              'role': 'assistant',
              'content': 'async openclaw reply',
              'createdAt': '2026-04-19T12:00:20.000Z',
            },
            {
              'messageId': 'user-second',
              'role': 'user',
              'content': 'second message',
              'createdAt': '2026-04-19T12:00:15.000Z',
            },
          ],
          'lastSeqId': 15,
        }),
        200,
      );
    });

    final service = ChatHistoryApiService(httpClient: client);
    final snapshot = await service.sync(
      token: 'token-1',
      sessionId: 'session:default:main',
      afterSeq: 10,
    );

    expect(snapshot.messages, hasLength(2));
    expect(snapshot.messages.first.messageId, equals('user-second'));
    expect(snapshot.messages.last.messageId, equals('assistant-async'));
    expect(snapshot.lastSeqId, equals(15));
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

  test(
    'filters transient empty assistant placeholder before persistence',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path.endsWith('/messages/batch'), isTrue);
        final decoded = jsonDecode(request.body) as Map<String, dynamic>;
        final messages =
            (decoded['messages'] as List).cast<Map<String, dynamic>>();
        expect(messages, hasLength(1));
        expect(messages.single['messageId'], equals('msg-user'));
        return http.Response(jsonEncode({'lastSeqId': 8}), 200);
      });

      final service = ChatHistoryApiService(httpClient: client);
      final lastSeq = await service.upsertMessages(
        token: 'token-1',
        messages: [
          ChatMessage(
            messageId: 'msg-user',
            role: 'user',
            content: 'DDD',
            channelId: 'default',
            sessionId: 'session:default:main',
          ),
          ChatMessage(
            messageId: 'msg-assistant',
            role: 'assistant',
            content: '',
            isStreaming: true,
            channelId: 'default',
            sessionId: 'session:default:main',
          ),
        ],
      );

      expect(lastSeq, equals(8));
    },
  );

  test('respond sends one backend-owned orchestration request', () async {
    final client = MockClient((request) async {
      expect(request.url.path.endsWith('/chat/respond'), isTrue);
      expect(request.method, equals('POST'));
      final decoded = jsonDecode(request.body) as Map<String, dynamic>;
      expect(decoded['taskId'], equals('task-2'));
      expect(decoded['userMessage'], equals('1+3'));
      return http.Response(
        jsonEncode({
          'text': '',
          'lastSeqId': 12,
          'mode': 'async',
          'state': 'accepted',
        }),
        200,
      );
    });

    final service = ChatHistoryApiService(httpClient: client);
    final result = await service.respond(
      token: 'token-1',
      taskId: 'task-2',
      idempotencyKey: 'idem-2',
      scope: const ChatSessionScope(channelId: 'default', threadId: 'main'),
      userMessageId: 'u-1',
      assistantMessageId: 'a-1',
      userMessage: '1+3',
      provider: 'anthropic',
      model: 'claude-sonnet-4-5',
    );

    expect(result.text, isEmpty);
    expect(result.lastSeqId, equals(12));
    expect(result.isAsync, isTrue);
    expect(result.taskState, ChatTaskState.accepted);
  });

  test(
    'respond maps openclaw async accepted state to sent-but-unread contract',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path.endsWith('/chat/respond'), isTrue);
        expect(request.method, equals('POST'));
        final decoded = jsonDecode(request.body) as Map<String, dynamic>;
        expect(decoded['channelId'], equals('default'));
        expect(decoded['threadId'], equals('main'));
        expect(decoded['taskId'], equals('task-openclaw-accepted'));
        return http.Response(
          jsonEncode({
            'text': '',
            'lastSeqId': 18,
            'mode': 'async',
            'state': 'accepted',
          }),
          200,
        );
      });

      final service = ChatHistoryApiService(httpClient: client);
      final result = await service.respond(
        token: 'token-1',
        taskId: 'task-openclaw-accepted',
        idempotencyKey: 'idem-openclaw-accepted',
        scope: const ChatSessionScope(channelId: 'default', threadId: 'main'),
        userMessageId: 'u-openclaw-1',
        assistantMessageId: 'a-openclaw-1',
        userMessage: 'ping openclaw',
      );

      expect(result.isAsync, isTrue);
      expect(result.taskState, ChatTaskState.accepted);
      expect(result.text, isEmpty);
      expect(result.lastSeqId, equals(18));
    },
  );

  test(
    'respond maps openclaw completed state to read-with-reply contract',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path.endsWith('/chat/respond'), isTrue);
        expect(request.method, equals('POST'));
        final decoded = jsonDecode(request.body) as Map<String, dynamic>;
        expect(decoded['taskId'], equals('task-openclaw-completed'));
        expect(decoded['userMessage'], equals('hello plugin'));
        return http.Response(
          jsonEncode({
            'text': 'plugin reply',
            'lastSeqId': 21,
            'mode': 'sync',
            'state': 'completed',
          }),
          200,
        );
      });

      final service = ChatHistoryApiService(httpClient: client);
      final result = await service.respond(
        token: 'token-1',
        taskId: 'task-openclaw-completed',
        idempotencyKey: 'idem-openclaw-completed',
        scope: const ChatSessionScope(channelId: 'default', threadId: 'main'),
        userMessageId: 'u-openclaw-2',
        assistantMessageId: 'a-openclaw-2',
        userMessage: 'hello plugin',
      );

      expect(result.isAsync, isFalse);
      expect(result.taskState, ChatTaskState.completed);
      expect(result.text, equals('plugin reply'));
      expect(result.lastSeqId, equals(21));
    },
  );

  test('loads persisted scopes for channel/sidebar hydration', () async {
    final client = MockClient((request) async {
      expect(request.url.path.endsWith('/chat/scopes'), isTrue);
      expect(request.method, equals('GET'));
      return http.Response(
        jsonEncode({
          'scopes': [
            {
              'channelId': 'channel-1',
              'threadId': 'sub-1',
              'sessionId': 'session:channel-1:sub-1',
              'lastActivityAt': '2026-04-09T10:00:00.000Z',
            },
            {
              'channelId': 'default',
              'threadId': 'main',
              'sessionId': 'session:default:main',
              'lastActivityAt': '2026-04-08T10:00:00.000Z',
            },
          ],
        }),
        200,
      );
    });

    final service = ChatHistoryApiService(httpClient: client);
    final scopes = await service.loadScopes(token: 'token-1');

    expect(scopes, hasLength(2));
    expect(scopes.first.channelId, equals('channel-1'));
    expect(scopes.first.threadId, equals('sub-1'));
    expect(scopes.first.sessionId, equals('session:channel-1:sub-1'));
  });

  test('loads scope settings and saves router updates', () async {
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        expect(request.url.path.endsWith('/chat/scope-settings'), isTrue);
        return http.Response(
          jsonEncode({
            'settings': [
              {
                'scopeType': 'channel',
                'channelId': 'default',
                'router': 'openclaw',
                'updatedAt': '2026-04-17T07:00:00.000Z',
              },
            ],
          }),
          200,
        );
      }

      expect(request.method, equals('PUT'));
      final decoded = jsonDecode(request.body) as Map<String, dynamic>;
      expect(decoded['scopeType'], equals('thread'));
      expect(decoded['channelId'], equals('default'));
      expect(decoded['threadId'], equals('main'));
      expect(decoded['router'], equals('default'));
      return http.Response(
        jsonEncode({
          'setting': {'router': 'default'},
        }),
        200,
      );
    });

    final service = ChatHistoryApiService(httpClient: client);
    final settings = await service.loadScopeSettings(token: 'token-1');
    await service.saveScopeSetting(
      token: 'token-1',
      scopeType: ChatScopeType.thread,
      channelId: 'default',
      threadId: 'main',
      router: ChatRouter.defaultRoute,
    );

    expect(settings, hasLength(1));
    expect(settings.single.scopeType, ChatScopeType.channel);
    expect(settings.single.router, ChatRouter.openclaw);
  });

  test('loads and saves channel name mappings', () async {
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        expect(request.url.path.endsWith('/chat/channel-names'), isTrue);
        return http.Response(
          jsonEncode({
            'channelNames': [
              {
                'channelId': 'channel-1',
                'displayName': 'renamed-channel',
              },
            ],
          }),
          200,
        );
      }

      expect(request.method, equals('PUT'));
      final decoded = jsonDecode(request.body) as Map<String, dynamic>;
      expect(decoded['channelId'], equals('channel-1'));
      expect(decoded['displayName'], equals('latest-channel-name'));
      return http.Response(
        jsonEncode({
          'setting': {
            'channelId': 'channel-1',
            'displayName': 'latest-channel-name',
          },
        }),
        200,
      );
    });

    final service = ChatHistoryApiService(httpClient: client);
    final channelNames = await service.loadChannelNames(token: 'token-1');
    await service.saveChannelName(
      token: 'token-1',
      channelId: 'channel-1',
      displayName: 'latest-channel-name',
    );

    expect(channelNames, hasLength(1));
    expect(channelNames.single.channelId, equals('channel-1'));
    expect(channelNames.single.displayName, equals('renamed-channel'));
  });

  test('listenEvents yields parsed snapshots from SSE data frames', () async {
    final controller = StreamController<List<int>>();

    final client = _MockStreamedClient((request) async {
      expect(request.method, equals('GET'));
      expect(request.url.path, contains('/chat/events/'));
      expect(request.url.queryParameters['afterSeq'], equals('5'));
      expect(request.headers['Authorization'], equals('Bearer sse-token'));
      return http.StreamedResponse(controller.stream, 200);
    });

    final service = ChatHistoryApiService(httpClient: client);
    final events = service.listenEvents(
      token: 'sse-token',
      sessionId: 'session:default:main',
      afterSeq: 5,
    );

    // Emit one SSE data frame via the stream controller.
    final eventJson = jsonEncode({
      'messages': [
        {
          'messageId': 'bot-1',
          'role': 'assistant',
          'content': 'hello from SSE',
          'createdAt': '2026-04-21T00:00:01.000Z',
        },
      ],
      'lastSeqId': 6,
    });
    controller.add(utf8.encode('data: $eventJson\n\n'));

    final snapshot = await events.first;
    await controller.close();

    expect(snapshot.messages, hasLength(1));
    expect(snapshot.messages.first.messageId, equals('bot-1'));
    expect(snapshot.lastSeqId, equals(6));
  });

  test('listenEvents ignores SSE heartbeat comments', () async {
    final controller = StreamController<List<int>>();

    final client = _MockStreamedClient((request) async {
      return http.StreamedResponse(controller.stream, 200);
    });

    final service = ChatHistoryApiService(httpClient: client);
    final events = service.listenEvents(
      token: 'token-1',
      sessionId: 'session:default:main',
      afterSeq: 0,
    );

    // Send a heartbeat comment followed by a real data frame.
    final eventJson = jsonEncode({
      'messages': [
        {'messageId': 'm-hb', 'role': 'user', 'content': 'hi'},
      ],
      'lastSeqId': 1,
    });
    controller.add(utf8.encode(': heartbeat\n\ndata: $eventJson\n\n'));

    final snapshot = await events.first;
    await controller.close();

    expect(snapshot.messages.first.messageId, equals('m-hb'));
    expect(snapshot.lastSeqId, equals(1));
  });
}
