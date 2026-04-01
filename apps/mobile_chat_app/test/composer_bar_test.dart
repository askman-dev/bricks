import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat_app/features/chat/widgets/composer_bar.dart';

void main() {
  testWidgets('does not show add or microphone buttons', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ComposerBar(
            agents: [],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.byIcon(Icons.mic_outlined), findsNothing);
  });

  testWidgets('submits typed message when send is tapped', (tester) async {
    String? sentText;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ComposerBar(
            agents: const [],
            onSend: (text) => sentText = text,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(sentText, equals('hello'));
  });
}
