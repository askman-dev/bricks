import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat_app/features/settings/llm_config_service.dart';
import 'package:mobile_chat_app/features/settings/openclaw_token_settings_screen.dart';
import 'package:mobile_chat_app/features/settings/settings_screen.dart';

class _FakeLlmConfigService extends LlmConfigService {
  const _FakeLlmConfigService();

  @override
  Future<PlatformTokenBundle> fetchPlatformToken({
    String pluginId = 'plugin_local_main',
  }) async {
    return const PlatformTokenBundle(
      token: 'platform-token-123',
      pluginId: 'plugin_local_main',
      baseUrl: 'https://bricks.askman.dev',
      scopes: ['events:read', 'events:ack'],
      expiresIn: '30d',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settings screen includes Openclaw Token item', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Openclaw Token'), findsOneWidget);
    await tester.tap(find.text('Openclaw Token'));
    await tester.pumpAndSettle();

    expect(find.text('Openclaw Token'), findsWidgets);
    expect(find.byType(OpenclawTokenSettingsScreen), findsOneWidget);
  });

  testWidgets('can generate and copy Openclaw Token', (tester) async {
    final clipboardCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardCalls.add(call);
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      const MaterialApp(
          home: OpenclawTokenSettingsScreen(service: _FakeLlmConfigService())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Openclaw Token'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Plugin ID:'), findsOneWidget);
    expect(
        find.widgetWithText(TextFormField, 'Openclaw Token'), findsOneWidget);
    expect(find.text('Install Instructions'), findsOneWidget);
    expect(find.textContaining('"channels"'), findsOneWidget);
    expect(find.textContaining('pluginId: plugin_local_main'), findsOneWidget);

    await tester.tap(find.byTooltip('Copy Openclaw Token'));
    await tester.pumpAndSettle();

    expect(clipboardCalls, hasLength(1));
    expect(clipboardCalls.single.arguments,
        containsPair('text', 'platform-token-123'));
    expect(find.text('Openclaw Token copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    final copyInstallInstructionsButton =
        find.byKey(const ValueKey('copyInstallInstructionsButton'));
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(copyInstallInstructionsButton.hitTestable());
    await tester.pumpAndSettle();

    expect(clipboardCalls, hasLength(2));
    final copiedInstruction = clipboardCalls.last.arguments['text'] as String;
    expect(copiedInstruction,
        contains('"BRICKS_BASE_URL": "https://bricks.askman.dev"'));
    expect(copiedInstruction, contains('scopes: events:read, events:ack'));
    expect(copiedInstruction, contains('token: platform-token-123'));
    expect(find.text('Install instructions copied'), findsOneWidget);
  });
}
