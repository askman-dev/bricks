import 'dart:io';
import 'package:project_system/project_system.dart';
import 'package:test/test.dart';

void main() {
  group('ProjectManifest', () {
    test('toMap / fromMap round-trip', () {
      const manifest = ProjectManifest(
        name: 'my-site',
        type: ProjectType.website,
        description: 'A test site',
        entryPoint: 'index.html',
        version: '0.2.0',
      );
      final map = manifest.toMap();
      final restored = ProjectManifest.fromMap(map);

      expect(restored.name, equals(manifest.name));
      expect(restored.type, equals(manifest.type));
      expect(restored.description, equals(manifest.description));
      expect(restored.entryPoint, equals(manifest.entryPoint));
      expect(restored.version, equals(manifest.version));
    });

    test('fromMap uses defaults when optional keys are absent', () {
      final manifest = ProjectManifest.fromMap({
        'name': 'bare',
        'type': 'website',
      });
      expect(manifest.entryPoint, equals('index.html'));
      expect(manifest.version, equals('0.1.0'));
      expect(manifest.description, isNull);
    });
  });

  group('WebsiteProjectFactory', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('bricks_proj_test_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('creates project directory with skeleton files', () async {
      const factory = WebsiteProjectFactory();
      final project = await factory.create(
        name: 'test-site',
        projectsBasePath: tempDir.path,
        description: 'A test site',
      );

      expect(project.name, equals('test-site'));
      expect(await Directory(project.path).exists(), isTrue);
      expect(
        await File('${project.path}${Platform.pathSeparator}index.html').exists(),
        isTrue,
      );
      expect(
        await File('${project.path}${Platform.pathSeparator}style.css').exists(),
        isTrue,
      );
      expect(
        await File('${project.path}${Platform.pathSeparator}script.js').exists(),
        isTrue,
      );
      expect(
        await File(
          '${project.path}${Platform.pathSeparator}bricks.project.yaml',
        ).exists(),
        isTrue,
      );
    });

    test('creates manifest with correct name and type', () async {
      const factory = WebsiteProjectFactory();
      final project = await factory.create(
        name: 'portfolio',
        projectsBasePath: tempDir.path,
      );
      expect(project.manifest.name, equals('portfolio'));
      expect(project.manifest.type, equals(ProjectType.website));
    });
  });

  group('WebsitePreviewService', () {
    test('previewUrl returns correct localhost URL', () {
      const service = WebsitePreviewService(localServerPort: 7474);
      final url = service.previewUrl('my-site');
      expect(url.host, equals('localhost'));
      expect(url.port, equals(7474));
      expect(url.path, equals('/my-site/index.html'));
    });
  });
}
