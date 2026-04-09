import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat_app/features/chat/chat_message.dart';
import 'package:mobile_chat_app/features/chat/widgets/message_list.dart';

List<ChatMessage> _messages(String prefix, int count) {
  final start = DateTime.utc(2026, 1, 1);
  return List<ChatMessage>.generate(
    count,
    (index) => ChatMessage(
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
    testWidgets('scrolls to bottom on first render', (tester) async {
      await tester.pumpWidget(_build(_messages('initial', 40)));
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);
    });

    testWidgets('scrolls to bottom when list content changes with same length',
        (tester) async {
      await tester.pumpWidget(_build(_messages('before', 40)));
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      scrollable.position.jumpTo(0);
      await tester.pump();
      expect(scrollable.position.pixels, 0);

      await tester.pumpWidget(_build(_messages('after', 40)));
      await tester.pumpAndSettle();

      expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);
    });
  });
}
