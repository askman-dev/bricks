import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat_app/features/chat/chat_message.dart';
import 'package:mobile_chat_app/features/chat/widgets/message_list.dart';

void main() {
  testWidgets('mouse drag selection shows highlight toolbar on web',
      (tester) async {
    String? highlightedText;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 500,
            child: MessageList(
              messages: [
                ChatMessage(
                  messageId: 'assistant-selection-target',
                  role: 'assistant',
                  content:
                      'Selection toolbar target text for browser validation.',
                  timestamp: DateTime.utc(2026, 1, 1),
                ),
              ],
              onHighlight: (messageId, selectedText, startOffset, endOffset) {
                highlightedText = selectedText;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final target = find.textContaining('Selection toolbar target text');
    expect(target, findsOneWidget);

    final box = tester.renderObject<RenderBox>(target);
    final topLeft = box.localToGlobal(Offset.zero);
    final y = topLeft.dy + box.size.height / 2;

    await tester.dragFrom(
      Offset(topLeft.dx + 4, y),
      Offset(box.size.width * 0.58, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('Highlight'), findsOneWidget);

    await tester.tap(find.text('Highlight'));
    await tester.pumpAndSettle();

    expect(highlightedText, isNotNull);
    expect(highlightedText, isNotEmpty);
  });

  testWidgets(
      'mouse drag selection toolbar copy button writes clipboard on web',
      (tester) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final arguments = call.arguments as Map<dynamic, dynamic>;
          copiedText = arguments['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 500,
            child: MessageList(
              messages: [
                ChatMessage(
                  messageId: 'assistant-copy-target',
                  role: 'assistant',
                  content: 'Copy toolbar target text for browser validation.',
                  timestamp: DateTime.utc(2026, 1, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final target = find.textContaining('Copy toolbar target text');
    expect(target, findsOneWidget);

    final box = tester.renderObject<RenderBox>(target);
    final topLeft = box.localToGlobal(Offset.zero);
    final y = topLeft.dy + box.size.height / 2;

    await tester.dragFrom(
      Offset(topLeft.dx + 4, y),
      Offset(box.size.width * 0.58, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('Copy'), findsOneWidget);

    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();

    expect(copiedText, isNotNull);
    expect(copiedText!.trim(), isNotEmpty);
  });
}
