import 'dart:io';
import 'package:test/test.dart';
import 'package:workspace_fs/workspace_fs.dart';

void main() {
  group('AgentsRepository', () {
    late Directory tempDir;
    late AgentsRepository repo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('bricks_agents_test_');
      repo = AgentsRepository(agentsPath: tempDir.path);
    });

    tearDown(() async => tempDir.deleteSync(recursive: true));

    test('listAgentNames returns empty when no agents exist', () async {
      expect(await repo.listAgentNames(), isEmpty);
    });

    test('saveAgent and loadAgent round-trip content', () async {
      const content = '---\nname: test\n---\nHello\n';
      await repo.saveAgent('test', content);

      final loaded = await repo.loadAgent('test');
      expect(loaded, equals(content));
    });

    test('saveAgent creates directory if missing', () async {
      final nested = AgentsRepository(
        agentsPath: '${tempDir.path}${Platform.pathSeparator}nested',
      );
      await nested.saveAgent('a', 'content');
      expect(await nested.loadAgent('a'), equals('content'));
    });

    test('listAgentNames returns saved agent names', () async {
      await repo.saveAgent('alpha', 'a');
      await repo.saveAgent('beta', 'b');
      final names = await repo.listAgentNames();
      expect(names, containsAll(['alpha', 'beta']));
    });

    test('listAgentNames ignores non-.md files', () async {
      // Create a non-.md file manually
      await File('${tempDir.path}${Platform.pathSeparator}readme.txt')
          .writeAsString('ignore me');
      await repo.saveAgent('real', 'content');

      final names = await repo.listAgentNames();
      expect(names, equals(['real']));
    });

    test('loadAgent returns null for unknown name', () async {
      expect(await repo.loadAgent('nonexistent'), isNull);
    });

    test('deleteAgent removes the file', () async {
      await repo.saveAgent('to-delete', 'content');
      expect(await repo.exists('to-delete'), isTrue);

      await repo.deleteAgent('to-delete');
      expect(await repo.exists('to-delete'), isFalse);
    });

    test('deleteAgent does nothing for nonexistent file', () async {
      // Should not throw
      await repo.deleteAgent('does-not-exist');
    });

    test('exists returns true for saved agent', () async {
      await repo.saveAgent('existing', 'content');
      expect(await repo.exists('existing'), isTrue);
    });

    test('exists returns false for unknown agent', () async {
      expect(await repo.exists('unknown'), isFalse);
    });

    test('loadAgent throws for path traversal name', () async {
      expect(
        () => repo.loadAgent('../escape'),
        throwsArgumentError,
      );
    });

    test('saveAgent throws for path traversal name', () async {
      expect(
        () => repo.saveAgent('../escape', 'content'),
        throwsArgumentError,
      );
    });

    test('deleteAgent throws for path traversal name', () async {
      expect(
        () => repo.deleteAgent('../escape'),
        throwsArgumentError,
      );
    });

    test('exists throws for path traversal name', () async {
      expect(
        () => repo.exists('../escape'),
        throwsArgumentError,
      );
    });

    test('saveAgent overwrites existing file', () async {
      await repo.saveAgent('update-me', 'version 1');
      await repo.saveAgent('update-me', 'version 2');
      expect(await repo.loadAgent('update-me'), equals('version 2'));
    });
  });
}
