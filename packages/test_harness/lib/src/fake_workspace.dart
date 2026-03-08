import 'dart:io';
import 'package:workspace_fs/workspace_fs.dart';

/// Creates a temporary workspace on the real filesystem for integration tests.
///
/// Call [create] in `setUp` and [dispose] in `tearDown`.
class FakeWorkspace {
  FakeWorkspace._({
    required this.tempDir,
    required this.locator,
    required this.repository,
  });

  final Directory tempDir;
  final WorkspaceLocator locator;
  final WorkspaceRepository repository;

  Workspace? _defaultWorkspace;
  Workspace get defaultWorkspace {
    assert(_defaultWorkspace != null, 'Call ensureDefault() first');
    return _defaultWorkspace!;
  }

  /// Creates a temporary directory and sets up the workspace structure.
  static Future<FakeWorkspace> create() async {
    final tempDir =
        await Directory.systemTemp.createTemp('bricks_fake_workspace_');
    final locator = WorkspaceLocator.withRoot(tempDir.path);
    await locator.ensureDirectories();
    final repository = WorkspaceRepository(locator: locator);
    return FakeWorkspace._(
      tempDir: tempDir,
      locator: locator,
      repository: repository,
    );
  }

  /// Ensures the default workspace exists and stores it for later use.
  Future<void> ensureDefault() async {
    _defaultWorkspace = await repository.ensureDefaultWorkspace();
  }

  /// Deletes the temporary directory.
  Future<void> dispose() async {
    await tempDir.delete(recursive: true);
  }
}
