import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:design_system/design_system.dart';
import 'package:mobile_chat_app/features/chat/chat_message.dart';
import 'package:mobile_chat_app/features/chat/widgets/message_list.dart';

List<ChatMessage> _messages(String prefix, int count) {
  final start = DateTime.utc(2026, 1, 1);
  return List<ChatMessage>.generate(
    count,
    (index) => ChatMessage(
      messageId: '$prefix-id-$index',
      role: index.isEven ? 'assistant' : 'user',
      content: '$prefix-$index',
      timestamp: start.add(Duration(minutes: index)),
    ),
  );
}

Widget _build(List<ChatMessage> messages) => MaterialApp(
      home: Scaffold(
        body: SizedBox(height: 320, child: MessageList(messages: messages)),
      ),
    );

void main() {
  group('MessageList auto scroll', () {
    testWidgets('focuses latest user message on first render', (tester) async {
      await tester.pumpWidget(_build(_messages('initial', 41)));
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scrollable.position.pixels,
          lessThan(scrollable.position.maxScrollExtent));
    });

    testWidgets('re-focuses latest user message when list content changes',
        (tester) async {
      await tester.pumpWidget(_build(_messages('before', 41)));
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      scrollable.position.jumpTo(0);
      await tester.pump();
      expect(scrollable.position.pixels, 0);

      await tester.pumpWidget(_build(_messages('after', 41)));
      await tester.pumpAndSettle();

      expect(scrollable.position.pixels, greaterThan(0));
    });

    testWidgets(
        're-focuses latest user message when rebuilt with same mutated list instance',
        (tester) async {
      final messages = _messages('before', 41);
      late StateSetter setState;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, stateSetter) {
                setState = stateSetter;
                return SizedBox(
                  height: 320,
                  child: MessageList(messages: messages),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      scrollable.position.jumpTo(0);
      await tester.pump();
      expect(scrollable.position.pixels, 0);

      messages
        ..clear()
        ..addAll(_messages('after', 41));
      setState(() {});
      await tester.pumpAndSettle();

      expect(scrollable.position.pixels, greaterThan(0));
    });
  });

  group('MessageList streaming without messageId', () {
    testWidgets(
        'does not re-scroll when streaming assistant message has null messageId',
        (tester) async {
      final userMsg = ChatMessage(
        messageId: 'u1',
        role: 'user',
        content: 'hello',
        timestamp: DateTime.utc(2026, 1, 1),
      );
      final streamingMsg = ChatMessage(
        // No messageId — simulates an in-flight assistant turn
        role: 'assistant',
        content: 'partial',
        timestamp: DateTime.utc(2026, 1, 1, 0, 1),
        isStreaming: true,
      );
      await tester.pumpWidget(_build([userMsg, streamingMsg]));
      // Pump a few frames to let the post-frame callbacks (scroll + layout) run.
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      final positionBefore = scrollable.position.pixels;

      // Simulate a streaming delta: same tail identity (same timestamp+role),
      // still streaming, content grows — should NOT trigger a re-scroll.
      final updatedMsg = ChatMessage(
        role: 'assistant',
        content: 'partial answer text',
        timestamp: DateTime.utc(2026, 1, 1, 0, 1),
        isStreaming: true,
      );
      await tester.pumpWidget(_build([userMsg, updatedMsg]));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(scrollable.position.pixels, positionBefore);
    });
  });

  group('MessageList message truncation', () {
    testWidgets('shows expand control only for overflowing user messages',
        (tester) async {
      final short = ChatMessage(
        messageId: 'short',
        role: 'user',
        content: 'short message',
        timestamp: DateTime.utc(2026, 1, 1),
      );
      final long = ChatMessage(
        messageId: 'long',
        role: 'user',
        content: List.filled(40, 'long content').join(' '),
        timestamp: DateTime.utc(2026, 1, 1, 0, 1),
      );
      await tester.pumpWidget(_build([short, long]));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.byTooltip('Expand'), findsOneWidget);
    });

    testWidgets('never shows expand control for assistant messages',
        (tester) async {
      final longAssistant = ChatMessage(
        messageId: 'long-a',
        role: 'assistant',
        content: List.filled(40, 'long assistant content').join(' '),
        timestamp: DateTime.utc(2026, 1, 1),
      );
      await tester.pumpWidget(_build([longAssistant]));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_more), findsNothing);
      expect(find.byTooltip('Expand'), findsNothing);
    });
  });

  testWidgets('does not render a decoration for assistant messages',
      (tester) async {
    final assistant = ChatMessage(
      messageId: 'assistant-plain',
      role: 'assistant',
      content: 'plain assistant content',
      timestamp: DateTime.utc(2026, 1, 1),
    );

    await tester.pumpWidget(_build([assistant]));
    await tester.pumpAndSettle();

    final assistantContainer = tester.widget<Container>(
      find.byKey(const ValueKey<String>('message-assistant-plain')),
    );
    expect(assistantContainer.decoration, isNull);
  });

  group('MessageList message width', () {
    testWidgets(
        'assistant message uses full list width while user stays compact',
        (tester) async {
      final user = ChatMessage(
        messageId: 'u',
        role: 'user',
        content: 'user content',
        timestamp: DateTime.utc(2026, 1, 1),
      );
      final assistant = ChatMessage(
        messageId: 'a',
        role: 'assistant',
        content: 'assistant content',
        timestamp: DateTime.utc(2026, 1, 1, 0, 1),
      );

      await tester.pumpWidget(_build([user, assistant]));
      await tester.pumpAndSettle();

      final userBox = tester.renderObject<RenderBox>(
        find.byKey(const ValueKey<String>('message-u')),
      );
      final assistantBox = tester.renderObject<RenderBox>(
        find.byKey(const ValueKey<String>('message-a')),
      );

      expect(assistantBox.size.width, greaterThan(userBox.size.width));
      expect(assistantBox.size.width, greaterThanOrEqualTo(330));
    });
  });

  group('Assistant markdown rendering', () {
    testWidgets(
        'renders markdown heading without heading marker and without size increase',
        (tester) async {
      final assistant = ChatMessage(
        messageId: 'assistant-markdown-heading',
        role: 'assistant',
        content: '# Heading line\nnormal paragraph',
        timestamp: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(_build([assistant]));
      await tester.pumpAndSettle();

      expect(find.text('# Heading line'), findsNothing);
      expect(find.text('Heading line'), findsOneWidget);

      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      RichText? headingRichText;
      RichText? paragraphRichText;
      for (final richText in richTexts) {
        final span = richText.text as TextSpan;
        final plain = span.toPlainText();
        if (plain == 'Heading line') {
          headingRichText = richText;
        }
        if (plain == 'normal paragraph') {
          paragraphRichText = richText;
        }
      }

      expect(headingRichText, isNotNull);
      expect(paragraphRichText, isNotNull);

      // Flutter wraps the TextSpan passed to Text.rich in an extra level with
      // the effective text style, so we traverse to the first leaf span that
      // carries a non-null style to reach the style actually applied by our
      // markdown renderer.
      TextStyle? firstLeafStyle(InlineSpan span) {
        if (span is TextSpan) {
          if (span.children != null && span.children!.isNotEmpty) {
            return firstLeafStyle(span.children!.first);
          }
          return span.style;
        }
        return null;
      }

      final headingStyle = firstLeafStyle(headingRichText!.text);
      final paragraphStyle = firstLeafStyle(paragraphRichText!.text);

      expect(headingStyle, isNotNull);
      expect(paragraphStyle, isNotNull);
      expect(headingStyle!.fontSize, paragraphStyle!.fontSize);
      expect(headingStyle.fontWeight, FontWeight.w700);
    });

    testWidgets('renders markdown list items with left indentation',
        (tester) async {
      final assistant = ChatMessage(
        messageId: 'assistant-markdown-list',
        role: 'assistant',
        content: '- first item',
        timestamp: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(_build([assistant]));
      await tester.pumpAndSettle();

      final markerFinder = find.text('-');
      expect(markerFinder, findsOneWidget);

      final padding = tester.widget<Padding>(
        find
            .ancestor(
              of: markerFinder,
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(padding.padding, const EdgeInsets.only(left: BricksSpacing.md));
    });
  });

  group('User delivery status', () {
    testWidgets('does not show status before user message is accepted',
        (tester) async {
      final user = ChatMessage(
        messageId: 'u-default',
        role: 'user',
        content: 'hello',
        taskId: 'task-default',
        timestamp: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(_build([user]));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('user-delivery-u-default')),
        findsNothing,
      );
    });

    testWidgets('shows one check for accepted user message before reply starts',
        (tester) async {
      final user = ChatMessage(
        messageId: 'u-default-accepted',
        role: 'user',
        content: 'hello',
        taskId: 'task-default-accepted',
        taskState: ChatTaskState.accepted,
        source: 'backend.respond',
        timestamp: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(_build([user]));
      await tester.pumpAndSettle();

      final row = find.byKey(
        const ValueKey<String>('user-delivery-u-default-accepted'),
      );
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      expect(find.descendant(of: row, matching: find.text('🦞')), findsNothing);
    });

    testWidgets('shows check + completed check when default router has replied',
        (tester) async {
      final user = ChatMessage(
        messageId: 'u-default-completed',
        role: 'user',
        content: 'hello',
        taskId: 'task-default-completed',
        taskState: ChatTaskState.accepted,
        source: 'backend.respond',
        timestamp: DateTime.utc(2026, 1, 1),
      );
      final assistant = ChatMessage(
        messageId: 'a-default-completed',
        role: 'assistant',
        content: 'done',
        taskId: 'task-default-completed',
        taskState: ChatTaskState.completed,
        timestamp: DateTime.utc(2026, 1, 1, 0, 1),
      );

      await tester.pumpWidget(_build([user, assistant]));
      await tester.pumpAndSettle();

      final row = find.byKey(
        const ValueKey<String>('user-delivery-u-default-completed'),
      );
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.check)),
        findsNWidgets(2),
      );
      final icons = tester.widgetList<Icon>(
        find.descendant(of: row, matching: find.byIcon(Icons.check)),
      );
      // Completed check inside user bubble uses the onUserMessageContainer
      // token from ChatColors — verifies the widget reads the theme token,
      // not a hard-coded color value.
      final chatColors =
          Theme.of(tester.element(find.byKey(
                const ValueKey<String>('user-delivery-u-default-completed'))))
              .extension<ChatColors>() ??
          ChatColors.light;
      expect(icons.last.color, chatColors.onUserMessageContainer);
    });

    testWidgets('shows check + lobster when openclaw reply starts',
        (tester) async {
      final user = ChatMessage(
        messageId: 'u-openclaw',
        role: 'user',
        content: 'hello',
        taskId: 'task-openclaw',
        taskState: ChatTaskState.accepted,
        source: 'backend.respond.openclaw',
        timestamp: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(_build([user]));
      await tester.pumpAndSettle();
      final beforeReplyRow = find.byKey(
        const ValueKey<String>('user-delivery-u-openclaw'),
      );
      expect(
        find.descendant(of: beforeReplyRow, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: beforeReplyRow, matching: find.text('🦞')),
        findsNothing,
      );

      final assistant = ChatMessage(
        messageId: 'a-openclaw',
        role: 'assistant',
        content: 'done',
        taskId: 'task-openclaw',
        taskState: ChatTaskState.accepted,
        timestamp: DateTime.utc(2026, 1, 1, 0, 1),
      );

      await tester.pumpWidget(_build([user, assistant]));
      await tester.pumpAndSettle();
      final afterReplyRow = find.byKey(
        const ValueKey<String>('user-delivery-u-openclaw'),
      );
      expect(
        find.descendant(of: afterReplyRow, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: afterReplyRow, matching: find.text('🦞')),
        findsOneWidget,
      );
    });
  });

  group('User bubble metadata and context menu', () {
    testWidgets('keeps user meta inside bubble and hides task id text',
        (tester) async {
      final user = ChatMessage(
        messageId: 'u-meta',
        role: 'user',
        content: 'hello',
        taskId: 'task-meta',
        taskState: ChatTaskState.accepted,
        threadId: 'sub-123',
        timestamp: DateTime.utc(2026, 1, 1, 7, 33),
      );

      await tester.pumpWidget(_build([user]));
      await tester.pumpAndSettle();

      expect(find.textContaining('task:accepted'), findsNothing);
      expect(find.textContaining('id:task-meta'), findsNothing);

      final bubble = find.byKey(const ValueKey<String>('message-u-meta'));
      final bubbleMeta = find.descendant(
        of: bubble,
        matching: find.textContaining('thread:sub-123'),
      );
      expect(bubbleMeta, findsOneWidget);
    });

    testWidgets('long press shows context menu with ids', (tester) async {
      final user = ChatMessage(
        messageId: 'u-menu',
        role: 'user',
        content: 'hello menu',
        taskId: 'task-menu',
        taskState: ChatTaskState.accepted,
        timestamp: DateTime.utc(2026, 1, 1, 7, 33),
      );

      await tester.pumpWidget(_build([user]));
      await tester.pumpAndSettle();

      await tester
          .longPress(find.byKey(const ValueKey<String>('message-u-menu')));
      await tester.pumpAndSettle();

      expect(find.text('复制'), findsOneWidget);
      expect(find.text('分叉（待开发）'), findsOneWidget);
      expect(find.text('重发（待开发）'), findsOneWidget);
      expect(find.text('message id: u-menu'), findsOneWidget);
      expect(find.text('task id: task-menu'), findsOneWidget);
    });
  });

  group('AI message avatar / header chip', () {
    testWidgets('shows dispatch placeholder header and loading state',
        (tester) async {
      final assistant = ChatMessage(
        messageId: 'a-dispatch',
        role: 'assistant',
        content: '',
        agentName: 'OpenClaw',
        taskState: ChatTaskState.dispatched,
        timestamp: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(_build([assistant]));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('OpenClaw'), findsOneWidget);
      expect(find.text('处理中…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows header for streaming AI message when identity is known',
        (tester) async {
      final assistant = ChatMessage(
        messageId: 'a-streaming',
        role: 'assistant',
        content: '...',
        model: 'claude-sonnet',
        isStreaming: true,
        timestamp: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(_build([assistant]));
      // Use pump() with a fixed duration instead of pumpAndSettle() because
      // streaming messages have ongoing animations that never fully settle.
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('claude-sonnet'), findsOneWidget);
    });

    testWidgets('shows model name as header chip once message is confirmed',
        (tester) async {
      final assistant = ChatMessage(
        messageId: 'a-confirmed',
        role: 'assistant',
        content: 'reply',
        model: 'claude-sonnet',
        timestamp: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(_build([assistant]));
      await tester.pumpAndSettle();

      expect(find.text('claude-sonnet'), findsOneWidget);
    });

    testWidgets('shows agentName over model when both are set', (tester) async {
      final assistant = ChatMessage(
        messageId: 'a-both',
        role: 'assistant',
        content: 'reply',
        agentName: 'openclaw aliyun',
        model: 'qwen-plus',
        timestamp: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(_build([assistant]));
      await tester.pumpAndSettle();

      expect(find.text('openclaw aliyun'), findsOneWidget);
      expect(find.text('qwen-plus'), findsNothing);
    });

    testWidgets('does not show header for confirmed AI message with no name',
        (tester) async {
      final assistant = ChatMessage(
        messageId: 'a-no-name',
        role: 'assistant',
        content: 'reply',
        timestamp: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(_build([assistant]));
      await tester.pumpAndSettle();

      // No agentName or model → no chip rendered; message content still visible
      expect(find.text('reply'), findsOneWidget);
    });

    testWidgets(
      'shows node name and nodeType label when both are present',
      (tester) async {
        final assistant = ChatMessage(
          messageId: 'a-node-type',
          role: 'assistant',
          content: 'hello',
          agentName: 'openclaw aliyun',
          nodeType: 'OpenClaw',
          timestamp: DateTime.utc(2026, 1, 1),
        );

        await tester.pumpWidget(_build([assistant]));
        await tester.pumpAndSettle();

        expect(find.text('openclaw aliyun'), findsOneWidget);
        expect(find.text('OpenClaw'), findsOneWidget);
      },
    );

    testWidgets(
      'does not show nodeType label when only agentName is set',
      (tester) async {
        final assistant = ChatMessage(
          messageId: 'a-no-type',
          role: 'assistant',
          content: 'hello',
          agentName: 'OpenClaw',
          timestamp: DateTime.utc(2026, 1, 1),
        );

        await tester.pumpWidget(_build([assistant]));
        await tester.pumpAndSettle();

        // agentName shown as the primary name, nodeType chip absent
        expect(find.text('OpenClaw'), findsOneWidget);
      },
    );
  });
}
