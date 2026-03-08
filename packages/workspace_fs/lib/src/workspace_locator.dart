import 'dart:io';

/// Locates the root Bricks directory on the device filesystem.
///
/// On mobile/desktop this resolves to `<documents>/bricks/`.
/// In tests, the root can be overridden via [WorkspaceLocator.withRoot].
class WorkspaceLocator {
  WorkspaceLocator({required String rootPath}) : _rootPath = rootPath;

  /// Creates a locator using the supplied absolute [rootPath].
  factory WorkspaceLocator.withRoot(String rootPath) =>
      WorkspaceLocator(rootPath: rootPath);

  final String _rootPath;

  /// The absolute path to the bricks root directory.
  String get rootPath => _rootPath;

  /// The absolute path to the `workspaces/` directory.
  String get workspacesPath => '$_rootPath${Platform.pathSeparator}workspaces';

  /// Ensures the root and workspaces directories exist.
  Future<void> ensureDirectories() async {
    await Directory(workspacesPath).create(recursive: true);
  }
}
