import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat_app/features/chat/chat_message.dart';
import 'package:mobile_chat_app/features/chat/chat_task_protocol.dart';
import 'package:mobile_chat_app/features/chat/chat_topology.dart';

void main() {
  test('resolves to default channel when requested channel is missing', () {
    const resolver = ChatTopologyResolver(defaultChannelId: 'default');

    final resolved = resolver.resolveChannelId(
      channels: const [
        ChatChannel(id: 'default', name: 'Default', isDefault: true),
        ChatChannel(id: 'c-2', name: 'Channel 2'),
      ],
      requestedChannelId: 'unknown',
    );

    expect(resolved, 'default');
  });

  test('parses router and scope type api values', () {
    expect(chatRouterFromApi('openclaw'), ChatRouter.openclaw);
    expect(chatRouterFromApi('default'), ChatRouter.defaultRoute);
    expect(chatScopeTypeFromApi('channel'), ChatScopeType.channel);
    expect(chatScopeTypeFromApi('thread'), ChatScopeType.thread);
    expect(ChatRouter.openclaw.apiValue, 'openclaw');
    expect(ChatScopeType.thread.apiValue, 'thread');
  });

  test('applies acknowledged state and cursor to message', () {
    final protocol = ChatTaskProtocol();
    final envelope = ChatTaskEnvelope(
      taskId: 'task-1',
      idempotencyKey: 'idem-1',
      createdAt: DateTime(2026, 4, 4),
      channelId: 'default',
      sessionId: 'session:default:main',
    );
    final ack = protocol.acknowledge(envelope);

    final message = ChatMessage(
      role: 'assistant',
      content: '',
      taskId: 'task-1',
      taskState: ChatTaskState.accepted,
    );

    final next = protocol.applyAcceptedState(message, ack);

    expect(next.taskState, ChatTaskState.dispatched);
    expect(next.acknowledgedAt, isNotNull);
    expect(next.checkpointCursor, startsWith('cursor:default:task-1'));
  });

  test(
    'does not apply acknowledged state when ack task id mismatches message task id',
    () {
      final protocol = ChatTaskProtocol();
      final envelope = ChatTaskEnvelope(
        taskId: 'task-2',
        idempotencyKey: 'idem-2',
        createdAt: DateTime(2026, 4, 4),
        channelId: 'default',
        sessionId: 'session:default:main',
      );
      final ack = protocol.acknowledge(envelope);

      final message = ChatMessage(
        role: 'assistant',
        content: '',
        taskId: 'task-1',
        taskState: ChatTaskState.accepted,
      );

      final next = protocol.applyAcceptedState(message, ack);

      expect(next.taskId, 'task-1');
      expect(next.taskState, ChatTaskState.accepted);
      expect(next.acknowledgedAt, isNull);
      expect(next.checkpointCursor, isNull);
    },
  );
}
