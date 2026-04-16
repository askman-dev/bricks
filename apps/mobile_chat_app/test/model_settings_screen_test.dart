import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat_app/features/settings/llm_config_service.dart';
import 'package:mobile_chat_app/features/settings/model_settings_screen.dart';

// ---------------------------------------------------------------------------
// Fake service – overrides network calls for tests.
// ---------------------------------------------------------------------------

class _FakeLlmConfigService extends LlmConfigService {
  _FakeLlmConfigService({
    List<LlmConfig>? configs,
    this.deleteThrows = false,
    this.platformTokenBundle = const PlatformTokenBundle(
      token: 'platform-token-123',
      pluginId: 'plugin_local_main',
      baseUrl: 'https://bricks.askman.dev',
      scopes: ['events:read', 'events:ack'],
      expiresIn: '30d',
    ),
  }) : _initialConfigs = configs ?? const [];

  final List<LlmConfig> _initialConfigs;
  final bool deleteThrows;
  final PlatformTokenBundle platformTokenBundle;

  final List<String> deletedIds = [];

  @override
  Future<List<LlmConfig>> fetchConfigs() async =>
      List<LlmConfig>.from(_initialConfigs);

  @override
  Future<LlmConfig> save(LlmConfig config) async =>
      config.copyWith(id: config.id ?? 'new-id');

  @override
  Future<void> deleteConfig(String id) async {
    if (deleteThrows) throw Exception('delete failed');
    deletedIds.add(id);
  }

  @override
  Future<PlatformTokenBundle> fetchPlatformToken({
    String pluginId = 'plugin_local_main',
  }) async =>
      platformTokenBundle;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _persistedConfig = LlmConfig(
  id: 'config-id-1',
  slotId: 'config-1',
  provider: LlmProvider.anthropic,
  baseUrl: 'https://api.anthropic.com',
  apiKey: '',
  defaultModel: 'claude-sonnet-4-5',
  isDefault: true,
);

const _unsavedConfig = LlmConfig(
  slotId: 'config-1',
  provider: LlmProvider.anthropic,
  baseUrl: 'https://api.anthropic.com',
  apiKey: '',
  defaultModel: 'claude-haiku-4-5',
  isDefault: true,
);

const _secondConfig = LlmConfig(
  id: 'config-id-2',
  slotId: 'config-2',
  provider: LlmProvider.anthropic,
  baseUrl: 'https://api.anthropic.com',
  apiKey: '',
  defaultModel: 'claude-haiku-4-5',
  isDefault: false,
);

Widget _buildScreen(LlmConfigService service) =>
    MaterialApp(home: ModelSettingsScreen(service: service));

Future<void> _scrollUntilVisible(
  WidgetTester tester,
  Finder target, {
  double delta = 300,
}) async {
  await tester.scrollUntilVisible(
    target,
    delta,
    scrollable: find.byType(Scrollable).first,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ModelSettingsScreen – delete flow', () {
    testWidgets('delete button shows confirmation dialog for persisted config',
        (tester) async {
      final service = _FakeLlmConfigService(configs: [_persistedConfig]);

      await tester.pumpWidget(_buildScreen(service));
      await tester.pumpAndSettle();

      await _scrollUntilVisible(tester, find.byIcon(Icons.delete_outline));
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Delete configuration?'), findsOneWidget);
    });

    testWidgets('canceling confirmation dialog does not delete config',
        (tester) async {
      final service = _FakeLlmConfigService(configs: [_persistedConfig]);

      await tester.pumpWidget(_buildScreen(service));
      await tester.pumpAndSettle();

      await _scrollUntilVisible(tester, find.byIcon(Icons.delete_outline));
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Dismiss via Cancel.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(service.deletedIds, isEmpty);
      // The chip for the config should still be visible.
      expect(find.text('claude-sonnet-4-5'), findsWidgets);
    });

    testWidgets('confirming dialog calls deleteConfig with the correct id',
        (tester) async {
      final service =
          _FakeLlmConfigService(configs: [_persistedConfig, _secondConfig]);

      await tester.pumpWidget(_buildScreen(service));
      await tester.pumpAndSettle();

      await _scrollUntilVisible(tester, find.byIcon(Icons.delete_outline));
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Tap the Delete button inside the AlertDialog (FilledButton).
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await tester.pumpAndSettle();

      expect(service.deletedIds, contains('config-id-1'));
      // Snackbar confirms deletion.
      expect(find.text('Model configuration deleted'), findsOneWidget);
    });

    testWidgets(
        'deleting unsaved config removes it locally without showing dialog',
        (tester) async {
      // First config has no id (unsaved); second is persisted.
      final service =
          _FakeLlmConfigService(configs: [_unsavedConfig, _secondConfig]);

      await tester.pumpWidget(_buildScreen(service));
      await tester.pumpAndSettle();

      // Active config is the first (unsaved) one.
      await _scrollUntilVisible(tester, find.byIcon(Icons.delete_outline));
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // No confirmation dialog should appear.
      expect(find.text('Delete configuration?'), findsNothing);
      // deleteConfig should NOT have been called.
      expect(service.deletedIds, isEmpty);
    });

    testWidgets('deleting the last config auto-adds a blank config',
        (tester) async {
      // Single unsaved config – deletion is immediate (no dialog).
      final service = _FakeLlmConfigService(configs: [_unsavedConfig]);

      await tester.pumpWidget(_buildScreen(service));
      await tester.pumpAndSettle();

      await _scrollUntilVisible(tester, find.byIcon(Icons.delete_outline));
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // The form should still be present (blank config was auto-added).
      expect(find.byType(Form), findsOneWidget);
      // A Delete button should still be visible.
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets(
        'delete and save buttons are both visible and initially enabled',
        (tester) async {
      final service = _FakeLlmConfigService(configs: [_persistedConfig]);

      await tester.pumpWidget(_buildScreen(service));
      await tester.pumpAndSettle();

      await _scrollUntilVisible(tester, find.byIcon(Icons.delete_outline));
      await _scrollUntilVisible(tester, find.byIcon(Icons.save_outlined));
      final deleteBtn = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.byIcon(Icons.delete_outline),
          matching: find.byType(OutlinedButton),
        ),
      );
      final saveBtn = tester.widget<FilledButton>(
        find.ancestor(
          of: find.byIcon(Icons.save_outlined),
          matching: find.byType(FilledButton),
        ),
      );

      expect(deleteBtn.onPressed, isNotNull);
      expect(saveBtn.onPressed, isNotNull);
    });

    testWidgets('shows error snackbar when deleteConfig throws',
        (tester) async {
      final service = _FakeLlmConfigService(
        configs: [_persistedConfig, _secondConfig],
        deleteThrows: true,
      );

      await tester.pumpWidget(_buildScreen(service));
      await tester.pumpAndSettle();

      await _scrollUntilVisible(tester, find.byIcon(Icons.delete_outline));
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Failed to delete model configuration'),
        findsOneWidget,
      );
    });
  });

  group('ModelSettingsScreen – copy actions', () {
    final clipboardCalls = <MethodCall>[];

    setUp(() {
      clipboardCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardCalls.add(call);
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('copy api url action copies base url to clipboard',
        (tester) async {
      final service = _FakeLlmConfigService(configs: [_persistedConfig]);
      await tester.pumpWidget(_buildScreen(service));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Copy API URL'));
      await tester.pumpAndSettle();

      expect(clipboardCalls, hasLength(1));
      expect(
        clipboardCalls.single.arguments,
        containsPair('text', 'https://api.anthropic.com'),
      );
      expect(find.text('API URL copied'), findsOneWidget);
    });

    testWidgets('copy api url action shows empty snackbar when field is blank',
        (tester) async {
      final service = _FakeLlmConfigService(configs: [_persistedConfig]);
      await tester.pumpWidget(_buildScreen(service));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Base URL'),
        '   ',
      );
      await tester.tap(find.byTooltip('Copy API URL'));
      await tester.pumpAndSettle();

      expect(clipboardCalls, isEmpty);
      expect(find.text('API URL is empty'), findsOneWidget);
    });

    testWidgets('copy api key action shows empty snackbar when field is blank',
        (tester) async {
      final service = _FakeLlmConfigService(configs: [_persistedConfig]);
      await tester.pumpWidget(_buildScreen(service));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Copy API Key'));
      await tester.pumpAndSettle();

      expect(clipboardCalls, isEmpty);
      expect(find.text('API Key is empty'), findsOneWidget);
    });

    testWidgets('copy api key action copies non-empty key to clipboard',
        (tester) async {
      final service = _FakeLlmConfigService(configs: [_persistedConfig]);
      await tester.pumpWidget(_buildScreen(service));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'API Key'), ' test-api-key ');
      await tester.tap(find.byTooltip('Copy API Key'));
      await tester.pumpAndSettle();

      expect(clipboardCalls, hasLength(1));
      expect(
        clipboardCalls.single.arguments,
        containsPair('text', 'test-api-key'),
      );
      expect(find.text('API Key copied'), findsOneWidget);
    });

    testWidgets('can fetch and copy xiaolongxia token', (tester) async {
      final service = _FakeLlmConfigService(configs: [_persistedConfig]);
      await tester.pumpWidget(_buildScreen(service));
      await tester.pumpAndSettle();

      await _scrollUntilVisible(
          tester, find.text('Get Xiaolongxia Token').first);
      await tester.tap(find.text('Get Xiaolongxia Token').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Plugin ID:'), findsOneWidget);
      expect(find.textContaining('Base URL:'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Xiaolongxia Token'),
          findsOneWidget);

      final copyTokenFinder = find.descendant(
        of: find.widgetWithText(TextFormField, 'Xiaolongxia Token'),
        matching: find.byIcon(Icons.copy_outlined),
      );
      await _scrollUntilVisible(tester, copyTokenFinder);
      await tester.ensureVisible(copyTokenFinder);
      await tester.pumpAndSettle();
      await tester.tap(copyTokenFinder);
      await tester.pumpAndSettle();

      expect(clipboardCalls, hasLength(1));
      expect(
        clipboardCalls.single.arguments,
        containsPair('text', 'platform-token-123'),
      );
      expect(find.textContaining('copied'), findsOneWidget);
    });
  });
}
