import 'dart:io';
import 'package:test/test.dart';
import 'package:workspace_fs/workspace_fs.dart';

void main() {
  group('WorkspaceLocator', () {
    test('exposes rootPath and workspacesPath', () {
      final locator = WorkspaceLocator.withRoot('/tmp/bricks_test');
      expect(locator.rootPath, equals('/tmp/bricks_test'));
      expect(
        locator.workspacesPath,
        equals('/tmp/bricks_test${Platform.pathSeparator}workspaces'),
      );
    });
  });

  group('WorkspaceRepository', () {
    late Directory tempDir;
    late WorkspaceLocator locator;
    late WorkspaceRepository repo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('bricks_ws_test_');
      locator = WorkspaceLocator.withRoot(tempDir.path);
      await locator.ensureDirectories();
      repo = WorkspaceRepository(locator: locator);
    });

    tearDown(() async => tempDir.deleteSync(recursive: true));

    test('listWorkspaces returns empty list when no workspaces exist', () async {
      expect(await repo.listWorkspaces(), isEmpty);
    });

    test('createWorkspace creates a directory with subdirectories', () async {
      final ws = await repo.createWorkspace('my-workspace');
      expect(ws.name, equals('my-workspace'));
      expect(await Directory(ws.path).exists(), isTrue);
      expect(
        await Directory('${ws.path}${Platform.pathSeparator}projects').exists(),
        isTrue,
      );
      expect(
        await Directory('${ws.path}${Platform.pathSeparator}conversations')
            .exists(),
        isTrue,
      );
      expect(
        await Directory('${ws.path}${Platform.pathSeparator}resources').exists(),
        isTrue,
      );
    });

    test('createWorkspace throws if workspace already exists', () async {
      await repo.createWorkspace('dup');
      expect(
        () => repo.createWorkspace('dup'),
        throwsA(isA<WorkspaceAlreadyExistsException>()),
      );
    });

    test('ensureDefaultWorkspace creates default if absent', () async {
      final ws = await repo.ensureDefaultWorkspace();
      expect(ws.name, equals('default'));
      expect(ws.isDefault, isTrue);
      expect(await Directory(ws.path).exists(), isTrue);
    });

    test('createWorkspace throws ArgumentError for path traversal name',
        () async {
      expect(
        () => repo.createWorkspace('../escape'),
        throwsArgumentError,
      );
      expect(
        () => repo.createWorkspace('a/b'),
        throwsArgumentError,
      );
      expect(
        () => repo.createWorkspace(''),
        throwsArgumentError,
      );
      // Standalone '..' is blocked; names with embedded dots are allowed
      expect(
        () => repo.createWorkspace('..'),
        throwsArgumentError,
      );
    });

    test('ensureDefaultWorkspace repairs missing subdirectories', () async {
      // Create the default dir without subdirs
      final path =
          '${locator.workspacesPath}${Platform.pathSeparator}default';
      await Directory(path).create(recursive: true);

      // Pre-populate metadata to verify it is preserved after repair
      final metaPath =
          '$path${Platform.pathSeparator}.bricks${Platform.pathSeparator}workspace.yaml';
      await Directory('$path${Platform.pathSeparator}.bricks')
          .create(recursive: true);
      await File(metaPath).writeAsString('name: default\ncreated_at: ORIGINAL\n');

      final ws = await repo.ensureDefaultWorkspace();
      expect(ws.isDefault, isTrue);
      expect(
        await Directory('$path${Platform.pathSeparator}projects').exists(),
        isTrue,
      );
      // Existing metadata must not be overwritten
      final metaContent = await File(metaPath).readAsString();
      expect(metaContent, contains('ORIGINAL'));
    });

    test('ensureDefaultWorkspace is idempotent', () async {
      await repo.ensureDefaultWorkspace();
      final ws2 = await repo.ensureDefaultWorkspace();
      expect(ws2.name, equals('default'));
    });

    test('listWorkspaces returns created workspaces', () async {
      await repo.createWorkspace('alpha');
      await repo.createWorkspace('beta');
      final names = (await repo.listWorkspaces()).map((w) => w.name).toList();
      expect(names, containsAll(['alpha', 'beta']));
    });
  });

  group('ConversationsRepository', () {
    late Directory tempDir;
    late ConversationsRepository repo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('bricks_conv_test_');
      repo = ConversationsRepository(workspacePath: tempDir.path);
    });

    tearDown(() async => tempDir.deleteSync(recursive: true));

    test('listConversationIds returns empty before any conversations', () async {
      expect(await repo.listConversationIds(), isEmpty);
    });

    test('saveConversation and loadConversation round-trips data', () async {
      await repo.saveConversation('conv-1', {'title': 'Hello', 'messages': []});
      final data = await repo.loadConversation('conv-1');
      expect(data, isNotNull);
      expect(data!['title'], equals('Hello'));
    });

    test('loadConversation throws for path traversal id', () async {
      expect(
        () => repo.loadConversation('../escape'),
        throwsArgumentError,
      );
    });

    test('saveConversation throws for path traversal id', () async {
      expect(
        () => repo.saveConversation('../escape', {}),
        throwsArgumentError,
      );
    });

    test('loadConversation returns null for unknown id', () async {
      expect(await repo.loadConversation('does-not-exist'), isNull);
    });
  });
}
