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

  group('sortChannelsByLastMessageAt', () {
    const chA = ChatChannel(id: 'a', name: 'Channel A');
    const chB = ChatChannel(id: 'b', name: 'Channel B', isDefault: true);
    const chC = ChatChannel(id: 'c', name: 'Channel C');

    final t1 = DateTime(2026, 1, 1);
    final t2 = DateTime(2026, 1, 2);
    final t3 = DateTime(2026, 1, 3);

    test('channel with newer last-message time appears first', () {
      final sorted = sortChannelsByLastMessageAt(
        [chA, chB],
        {chA.id: t1, chB.id: t2},
      );
      expect(sorted.map((c) => c.id), ['b', 'a']);
    });

    test('channel with a last-message time sorts before one without', () {
      final sorted = sortChannelsByLastMessageAt(
        [chA, chB],
        {chA.id: t1},
      );
      expect(sorted.first.id, 'a');
      expect(sorted.last.id, 'b');
    });

    test('channels without any last-message time use id as tie-breaker', () {
      final sorted = sortChannelsByLastMessageAt([chC, chA, chB], {});
      expect(sorted.map((c) => c.id), ['a', 'b', 'c']);
    });

    test('default channel participates in sort – sorts by time, not isDefault',
        () {
      // chB is the default channel but has an older time; chA should be first.
      final sorted = sortChannelsByLastMessageAt(
        [chB, chA],
        {chB.id: t1, chA.id: t2},
      );
      expect(sorted.first.id, 'a',
          reason: 'Regular channel with newer time beats default channel');
      expect(sorted.last.id, 'b');
    });

    test('default channel with newest time sorts first', () {
      final sorted = sortChannelsByLastMessageAt(
        [chA, chB, chC],
        {chA.id: t1, chB.id: t3, chC.id: t2},
      );
      expect(sorted.map((c) => c.id), ['b', 'c', 'a']);
    });

    test('channels with equal last-message time are ordered deterministically by id', () {
      final sorted = sortChannelsByLastMessageAt(
        [chC, chA, chB],
        {chA.id: t1, chB.id: t1, chC.id: t1},
      );
      // All times are equal, so fallback to id lexicographic order.
      expect(sorted.map((c) => c.id), ['a', 'b', 'c']);
    });

    test('does not modify the original list', () {
      final original = [chB, chA];
      sortChannelsByLastMessageAt(original, {chA.id: t2, chB.id: t1});
      expect(original.map((c) => c.id), ['b', 'a'],
          reason: 'Original list must not be mutated');
    });
  });
}
