import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  group('MessageList message truncation', () {
    testWidgets('shows expand control only for overflowing messages',
        (tester) async {
      final short = ChatMessage(
        messageId: 'short',
        role: 'assistant',
        content: 'short message',
        timestamp: DateTime.utc(2026, 1, 1),
      );
      final long = ChatMessage(
        messageId: 'long',
        role: 'assistant',
        content: List.filled(40, 'long content').join(' '),
        timestamp: DateTime.utc(2026, 1, 1, 0, 1),
      );
      await tester.pumpWidget(_build([short, long]));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.byTooltip('Expand'), findsOneWidget);
    });
  });

  group('MessageList bubble width', () {
    testWidgets(
        'assistant bubble uses full list width while user stays compact',
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
        find.byKey(const ValueKey<String>('bubble-u')),
      );
      final assistantBox = tester.renderObject<RenderBox>(
        find.byKey(const ValueKey<String>('bubble-a')),
      );

      expect(assistantBox.size.width, greaterThan(userBox.size.width));
      expect(assistantBox.size.width, greaterThanOrEqualTo(320));
    });
  });
}
