import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:design_system/design_system.dart';
import 'package:mobile_chat_app/features/chat/chat_message.dart';
import 'package:mobile_chat_app/features/chat/widgets/message_list.dart';

// Must match _kBottomPaddingRatio in message_list.dart
const double _kTestBottomPaddingRatio = 0.75;

/// Computes the expected latest-content anchor offset using the same formula
/// as MessageList._latestContentAnchorOffset.
double _latestAnchorOffset(WidgetTester tester, ScrollPosition position) {
  final screenHeight =
      tester.view.physicalSize.height / tester.view.devicePixelRatio;
  return (position.maxScrollExtent -
          (BricksSpacing.md + screenHeight * _kTestBottomPaddingRatio))
      .clamp(position.minScrollExtent, position.maxScrollExtent);
}

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

Widget _build(
  List<ChatMessage> messages, {
  ThemeData? theme,
  Map<String, List<HighlightSpan>> highlights = const {},
  void Function(String, String, int?, int?)? onHighlight,
  void Function(String)? onDeleteHighlight,
}) =>
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: SizedBox(
          height: 320,
          child: MessageList(
            messages: messages,
            highlights: highlights,
            onHighlight: onHighlight,
            onDeleteHighlight: onDeleteHighlight,
          ),
        ),
      ),
    );

Iterable<TextSpan> _leafTextSpans(InlineSpan span) sync* {
  if (span is TextSpan) {
    final children = span.children;
    if (children == null || children.isEmpty) {
      yield span;
      return;
    }
    for (final child in children) {
      yield* _leafTextSpans(child);
    }
  }
}

List<TextSpan> _decoratedLeafSpans(WidgetTester tester) {
  return tester
      .widgetList<RichText>(find.byType(RichText))
      .expand((richText) => _leafTextSpans(richText.text))
      .where((span) => span.style?.decoration == TextDecoration.underline)
      .toList();
}

void main() {
  group('MessageList auto scroll', () {
    testWidgets('focuses latest user message on first render', (tester) async {
      await tester.pumpWidget(_build(_messages('initial', 41)));
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scrollable.position.pixels,
          lessThan(scrollable.position.maxScrollExtent));
    });

    testWidgets(
        're-focuses latest user message when channel messages are replaced',
        (tester) async {
      final messages = _messages('channel-a', 61);
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
        ..addAll(_messages('channel-b', 61));
      setState(() {});
      await tester.pumpAndSettle();

      expect(scrollable.position.pixels, greaterThan(0));
    });

    testWidgets('keeps scroll position when only assistant message is appended',
        (tester) async {
      final messages = _messages('stable', 61);
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
      final midOffset = scrollable.position.maxScrollExtent * 0.5;
      scrollable.position.jumpTo(midOffset);
      await tester.pump();
      final before = scrollable.position.pixels;
      expect(before, greaterThan(0));

      messages.add(
        ChatMessage(
          messageId: 'a1',
          role: 'assistant',
          content: 'partial answer',
          timestamp: DateTime.utc(2026, 1, 1, 0, 1, 1),
        ),
      );
      setState(() {});
      await tester.pumpAndSettle();

      expect(scrollable.position.pixels, closeTo(before, 0.1));
    });

    testWidgets(
        'keeps reading position when a new user message is appended while away from latest',
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
      final before = scrollable.position.pixels;
      expect(before, 0);

      messages.add(
        ChatMessage(
          messageId: 'u-new',
          role: 'user',
          content: 'new question',
          timestamp: DateTime.utc(2026, 1, 1, 10),
        ),
      );
      setState(() {});
      await tester.pumpAndSettle();

      expect(scrollable.position.pixels, closeTo(before, 0.1));
    });

    testWidgets(
        're-focuses latest user message when a new user message is appended from latest',
        (tester) async {
      final messages = _messages('before-latest', 41);
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
      final latestAnchor = _latestAnchorOffset(tester, scrollable.position);
      scrollable.position.jumpTo(latestAnchor);
      await tester.pump();
      final before = scrollable.position.pixels;

      messages.add(
        ChatMessage(
          messageId: 'u-new-latest',
          role: 'user',
          content: 'new question from latest',
          timestamp: DateTime.utc(2026, 1, 1, 10),
        ),
      );
      setState(() {});
      await tester.pumpAndSettle();

      expect(scrollable.position.pixels, greaterThan(before));
      expect(find.text('new question from latest'), findsOneWidget);
    });

    testWidgets(
        'shows jump-to-latest button when over two screens away and scrolls to latest anchor on tap',
        (tester) async {
      await tester.pumpWidget(_build(_messages('jump', 60)));
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      scrollable.position.jumpTo(0);
      await tester.pump();

      final jumpButton = find.byTooltip('Jump to latest');
      expect(jumpButton, findsOneWidget);

      // Compute the expected anchor BEFORE tapping so it uses the same
      // maxScrollExtent the production code will see when the button is pressed.
      final expectedAnchor = _latestAnchorOffset(tester, scrollable.position);

      await tester.tap(jumpButton);
      await tester.pumpAndSettle();

      expect(scrollable.position.pixels, closeTo(expectedAnchor, 1.0));
    });

    testWidgets(
        'keeps jump-to-latest button hidden when under two screens away',
        (tester) async {
      await tester.pumpWidget(_build(_messages('near', 60)));
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      final nearAnchor = _latestAnchorOffset(tester, scrollable.position);
      final almostNearEnough =
          nearAnchor - scrollable.position.viewportDimension * 1.9;
      scrollable.position.jumpTo(almostNearEnough.clamp(
        scrollable.position.minScrollExtent,
        scrollable.position.maxScrollExtent,
      ));
      await tester.pump();

      final beforeTap = scrollable.position.pixels;
      await tester.tap(find.byTooltip('Jump to latest'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, closeTo(beforeTap, 0.1));
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

  group('MessageList visual style', () {
    testWidgets('uses high-contrast user bubble colors in dark mode',
        (tester) async {
      final user = ChatMessage(
        messageId: 'u-dark',
        role: 'user',
        content: 'dark mode user message',
        timestamp: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(_build([user], theme: BricksTheme.dark()));
      await tester.pumpAndSettle();

      final userContainer = tester.widget<Container>(
        find.byKey(const ValueKey<String>('message-u-dark')),
      );
      final decoration = userContainer.decoration! as BoxDecoration;
      expect(decoration.color, const Color(0xFFE9EBEC));

      final userText = tester.widget<Text>(find.text('dark mode user message'));
      expect(userText.style?.color, const Color(0xFF1F2328));
    });

    testWidgets('adds larger gap after user bubbles', (tester) async {
      final user = ChatMessage(
        messageId: 'u-gap',
        role: 'user',
        content: 'first message',
        timestamp: DateTime.utc(2026, 1, 1),
      );
      final assistant = ChatMessage(
        messageId: 'a-gap',
        role: 'assistant',
        content: 'second message',
        timestamp: DateTime.utc(2026, 1, 1, 0, 1),
      );

      await tester.pumpWidget(_build([user, assistant]));
      await tester.pumpAndSettle();

      final userContainer = tester.widget<Container>(
        find.byKey(const ValueKey<String>('message-u-gap')),
      );
      expect(
        userContainer.margin,
        const EdgeInsets.only(bottom: BricksSpacing.md),
      );
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

    testWidgets('renders nested markdown list items with deeper indentation',
        (tester) async {
      final assistant = ChatMessage(
        messageId: 'assistant-markdown-nested-list',
        role: 'assistant',
        content: '- parent\n  - child target\n    1. grandchild',
        timestamp: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(_build([assistant]));
      await tester.pumpAndSettle();

      EdgeInsets paddingForText(String text) {
        return tester
            .widget<Padding>(
              find
                  .ancestor(
                    of: find.text(text),
                    matching: find.byType(Padding),
                  )
                  .first,
            )
            .padding as EdgeInsets;
      }

      final parentPadding = paddingForText('parent');
      final childPadding = paddingForText('child target');
      final grandchildPadding = paddingForText('grandchild');

      expect(childPadding.left, greaterThan(parentPadding.left));
      expect(grandchildPadding.left, greaterThan(childPadding.left));
      expect(find.text('1.'), findsOneWidget);
    });

    testWidgets('renders markdown tables as table widgets', (tester) async {
      final assistant = ChatMessage(
        messageId: 'assistant-markdown-table',
        role: 'assistant',
        content: '''
| 参数 | 含义 |
|---|---|
| `flutter run` | Flutter 的开发运行命令 |
| `-d chrome` | 指定 Chrome 设备 |
''',
        timestamp: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(_build([assistant]));
      await tester.pumpAndSettle();

      expect(find.byType(Table), findsOneWidget);
      expect(find.text('| 参数 | 含义 |'), findsNothing);
      expect(find.text('参数'), findsOneWidget);
      expect(find.text('含义'), findsOneWidget);
      expect(find.text('Flutter 的开发运行命令'), findsOneWidget);
      expect(find.text('指定 Chrome 设备'), findsOneWidget);
    });
  });

  group('Assistant highlights', () {
    testWidgets('uses stored offsets instead of highlighting duplicate text',
        (tester) async {
      final assistant = ChatMessage(
        messageId: 'assistant-highlight-duplicates',
        role: 'assistant',
        content: 'repeat repeat',
        timestamp: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(
        _build(
          [assistant],
          highlights: const {
            'assistant-highlight-duplicates': [
              HighlightSpan(
                highlightId: 'h1',
                selectedText: 'repeat',
                startOffset: 7,
                endOffset: 13,
                color: 'yellow',
              ),
            ],
          },
        ),
      );
      await tester.pumpAndSettle();

      final decorated = _decoratedLeafSpans(tester);
      expect(decorated.map((span) => span.text).toList(), ['repeat']);
    });

    testWidgets('splits one cross-paragraph highlight into subsegments',
        (tester) async {
      final assistant = ChatMessage(
        messageId: 'assistant-highlight-paragraphs',
        role: 'assistant',
        content: 'first line\nsecond line',
        timestamp: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(
        _build(
          [assistant],
          highlights: const {
            'assistant-highlight-paragraphs': [
              HighlightSpan(
                highlightId: 'h1',
                selectedText: 'line\nsecond',
                startOffset: 6,
                endOffset: 17,
                color: 'yellow',
              ),
            ],
          },
        ),
      );
      await tester.pumpAndSettle();

      final decorated = _decoratedLeafSpans(tester);
      expect(decorated.map((span) => span.text).toList(), ['line', 'second']);
    });

    testWidgets('renders stored ranges inside code blocks', (tester) async {
      final assistant = ChatMessage(
        messageId: 'assistant-highlight-code',
        role: 'assistant',
        content: '```dart\nfinal answer = 42;\n```',
        timestamp: DateTime.utc(2026, 1, 1),
      );
      const start = '```dart\nfinal '.length;

      await tester.pumpWidget(
        _build(
          [assistant],
          highlights: const {
            'assistant-highlight-code': [
              HighlightSpan(
                highlightId: 'h1',
                selectedText: 'answer',
                startOffset: start,
                endOffset: start + 6,
                color: 'yellow',
              ),
            ],
          },
        ),
      );
      await tester.pumpAndSettle();

      final decorated = _decoratedLeafSpans(tester);
      expect(decorated.map((span) => span.text).toList(), ['answer']);
      expect(decorated.single.style?.fontFamily, 'monospace');
    });

    testWidgets('renders stored ranges inside markdown table cells',
        (tester) async {
      const content = '''
| Name | Value |
|---|---|
| first | target |
''';
      final assistant = ChatMessage(
        messageId: 'assistant-highlight-table',
        role: 'assistant',
        content: content,
        timestamp: DateTime.utc(2026, 1, 1),
      );
      final start = content.indexOf('target');

      await tester.pumpWidget(
        _build(
          [assistant],
          highlights: {
            'assistant-highlight-table': [
              HighlightSpan(
                highlightId: 'h1',
                selectedText: 'target',
                startOffset: start,
                endOffset: start + 'target'.length,
                color: 'yellow',
              ),
            ],
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Table), findsOneWidget);
      final decorated = _decoratedLeafSpans(tester);
      expect(decorated.map((span) => span.text).toList(), ['target']);
    });

    testWidgets('renders stored ranges inside nested markdown list items',
        (tester) async {
      const content = '- parent\n  - child target\n    1. grandchild';
      final assistant = ChatMessage(
        messageId: 'assistant-highlight-nested-list',
        role: 'assistant',
        content: content,
        timestamp: DateTime.utc(2026, 1, 1),
      );
      final start = content.indexOf('target');

      await tester.pumpWidget(
        _build(
          [assistant],
          highlights: {
            'assistant-highlight-nested-list': [
              HighlightSpan(
                highlightId: 'h1',
                selectedText: 'target',
                startOffset: start,
                endOffset: start + 'target'.length,
                color: 'yellow',
              ),
            ],
          },
        ),
      );
      await tester.pumpAndSettle();

      final decorated = _decoratedLeafSpans(tester);
      expect(decorated.map((span) => span.text).toList(), ['target']);
    });

    testWidgets('merges overlapping highlights without duplicating text',
        (tester) async {
      const content = '0123456789';
      final assistant = ChatMessage(
        messageId: 'assistant-highlight-overlap',
        role: 'assistant',
        content: content,
        timestamp: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(
        _build(
          [assistant],
          highlights: const {
            'assistant-highlight-overlap': [
              HighlightSpan(
                highlightId: 'h1',
                selectedText: '2345',
                startOffset: 2,
                endOffset: 6,
                color: 'yellow',
              ),
              HighlightSpan(
                highlightId: 'h2',
                selectedText: '4567',
                startOffset: 4,
                endOffset: 8,
                color: 'yellow',
              ),
            ],
          },
        ),
      );
      await tester.pumpAndSettle();

      final richText = tester
          .widgetList<RichText>(find.byType(RichText))
          .firstWhere((widget) => widget.text.toPlainText() == content);
      expect(richText.text.toPlainText(), content);
      final decorated = _decoratedLeafSpans(tester);
      expect(decorated.map((span) => span.text).toList(), ['234567']);
    });

    testWidgets('tapping highlighted text shows copy and delete toolbar',
        (tester) async {
      String? deletedHighlightId;
      final assistant = ChatMessage(
        messageId: 'assistant-highlight-tap',
        role: 'assistant',
        content: 'tap target text',
        timestamp: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(
        _build(
          [assistant],
          highlights: const {
            'assistant-highlight-tap': [
              HighlightSpan(
                highlightId: 'h-delete',
                selectedText: 'target',
                startOffset: 4,
                endOffset: 10,
                color: 'yellow',
              ),
            ],
          },
          onDeleteHighlight: (highlightId) {
            deletedHighlightId = highlightId;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('tap target text'));
      await tester.pumpAndSettle();

      expect(find.text('复制'), findsOneWidget);
      expect(find.text('删除划线'), findsOneWidget);

      await tester.tap(find.text('删除划线'));
      await tester.pumpAndSettle();

      expect(deletedHighlightId, 'h-delete');
    });

    testWidgets('delete toolbar sizes to longer action label', (tester) async {
      final assistant = ChatMessage(
        messageId: 'assistant-highlight-toolbar-size',
        role: 'assistant',
        content: 'tap target text',
        timestamp: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(
        _build(
          [assistant],
          highlights: const {
            'assistant-highlight-toolbar-size': [
              HighlightSpan(
                highlightId: 'h-delete',
                selectedText: 'target',
                startOffset: 4,
                endOffset: 10,
                color: 'yellow',
              ),
            ],
          },
          onHighlight: (_, __, ___, ____) {},
          onDeleteHighlight: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      await tester.dragFrom(
        tester.getCenter(find.textContaining('tap target text')),
        const Offset(48, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      final shortMaterial = find
          .ancestor(
            of: find.text('划线'),
            matching: find.byType(Material),
          )
          .first;
      final shortRightPadding = tester.getRect(shortMaterial).right -
          tester.getRect(find.text('划线')).right;
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('tap target text'));
      await tester.pumpAndSettle();
      final deleteMaterial = find
          .ancestor(
            of: find.text('删除划线'),
            matching: find.byType(Material),
          )
          .first;
      final deleteRightPadding = tester.getRect(deleteMaterial).right -
          tester.getRect(find.text('删除划线')).right;

      expect(deleteRightPadding, greaterThanOrEqualTo(shortRightPadding));
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
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.hub_outlined)),
        findsNothing,
      );
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
      // Completed check inside user bubble uses the onMessageUser
      // token from ChatColors — verifies the widget reads the theme token,
      // not a hard-coded color value.
      final chatColors = Theme.of(tester.element(find.byKey(
                  const ValueKey<String>('user-delivery-u-default-completed'))))
              .extension<ChatColors>() ??
          ChatColors.light;
      expect(icons.last.color, chatColors.onMessageUser);
    });

    testWidgets('shows check + openclaw icon when openclaw reply starts',
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
        find.descendant(
          of: beforeReplyRow,
          matching: find.byIcon(Icons.hub_outlined),
        ),
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
        find.descendant(
          of: afterReplyRow,
          matching: find.byIcon(Icons.hub_outlined),
        ),
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

  group('Agent-loop status rows', () {
    testWidgets('tool_call_start renders spinning indicator and label',
        (tester) async {
      final msg = ChatMessage(
        messageId: 'tc-start-1',
        role: 'assistant',
        content: '',
        agentLoopPhase: 'tool_call_start',
        agentLoopTool: 'search_web',
        timestamp: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(_build([msg]));
      // Use pump() not pumpAndSettle() because CircularProgressIndicator
      // has an ongoing animation that never fully settles.
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('search_web'), findsOneWidget);
    });

    testWidgets('tool_call_start without toolName renders generic label',
        (tester) async {
      final msg = ChatMessage(
        messageId: 'tc-start-2',
        role: 'assistant',
        content: '',
        agentLoopPhase: 'tool_call_start',
        timestamp: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(_build([msg]));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('正在调用工具…'), findsOneWidget);
    });

    testWidgets('reasoning renders collapsed thought block by default',
        (tester) async {
      final msg = ChatMessage(
        messageId: 'reasoning-1',
        role: 'assistant',
        content: 'Step 1: check constraints. Step 2: compute.',
        agentLoopPhase: 'reasoning',
        timestamp: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(_build([msg]));
      await tester.pumpAndSettle();

      // Header with psychology icon and label visible
      expect(find.byIcon(Icons.psychology_outlined), findsOneWidget);
      expect(find.text('思考过程'), findsOneWidget);
      // Reasoning content is hidden when collapsed
      expect(find.text('Step 1: check constraints. Step 2: compute.'),
          findsNothing);
    });

    testWidgets('reasoning expands and collapses on tap', (tester) async {
      final msg = ChatMessage(
        messageId: 'reasoning-2',
        role: 'assistant',
        content: 'I reasoned carefully.',
        agentLoopPhase: 'reasoning',
        timestamp: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(_build([msg]));
      await tester.pumpAndSettle();

      // Initially collapsed
      expect(find.text('I reasoned carefully.'), findsNothing);

      // Tap the header to expand
      await tester.tap(find.text('思考过程'));
      await tester.pumpAndSettle();

      // Content now visible
      expect(find.text('I reasoned carefully.'), findsOneWidget);

      // Tap again to collapse
      await tester.tap(find.text('思考过程'));
      await tester.pumpAndSettle();

      expect(find.text('I reasoned carefully.'), findsNothing);
    });

    testWidgets('step_text renders text with left accent border',
        (tester) async {
      final msg = ChatMessage(
        messageId: 'pt-1',
        role: 'assistant',
        content: 'Let me look that up.',
        agentLoopPhase: 'step_text',
        timestamp: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(_build([msg]));
      await tester.pumpAndSettle();

      expect(find.text('Let me look that up.'), findsOneWidget);
      // The left border is an IntrinsicHeight → Row containing a narrow
      // Container followed by the text.
      expect(find.byType(IntrinsicHeight), findsOneWidget);
    });

    testWidgets(
        'tool_call phase falls through to normal assistant bubble rendering',
        (tester) async {
      final msg = ChatMessage(
        messageId: 'tc-result-1',
        role: 'assistant',
        content: 'Tool: search\nResult: {"title":"Flutter"}',
        agentLoopPhase: 'tool_call',
        timestamp: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(_build([msg]));
      await tester.pumpAndSettle();

      // Content visible in the normal rendering path
      expect(find.textContaining('Tool: search'), findsOneWidget);
      // No spinner (would only appear for tool_call_start)
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
