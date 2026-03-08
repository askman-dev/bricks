import 'dart:io';
import 'workspace_locator.dart';

/// Metadata about a workspace directory.
class Workspace {
  const Workspace({
    required this.name,
    required this.path,
    this.isDefault = false,
  });

  final String name;
  final String path;
  final bool isDefault;
}

/// Manages workspace directories on the local filesystem.
class WorkspaceRepository {
  WorkspaceRepository({required WorkspaceLocator locator})
      : _locator = locator;

  final WorkspaceLocator _locator;

  /// Returns all workspace directories.
  Future<List<Workspace>> listWorkspaces() async {
    final dir = Directory(_locator.workspacesPath);
    if (!await dir.exists()) return [];

    final workspaces = <Workspace>[];
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final name = entity.path.split(Platform.pathSeparator).last;
        workspaces.add(
          Workspace(name: name, path: entity.path, isDefault: name == 'default'),
        );
      }
    }
    return workspaces;
  }

  /// Creates a new workspace directory with the given [name].
  ///
  /// Throws [WorkspaceAlreadyExistsException] if a workspace with that name
  /// already exists.
  Future<Workspace> createWorkspace(String name) async {
    final path = '${_locator.workspacesPath}${Platform.pathSeparator}$name';
    final dir = Directory(path);

    if (await dir.exists()) {
      throw WorkspaceAlreadyExistsException(name);
    }

    await dir.create(recursive: true);
    await _createWorkspaceStructure(path, name);

    return Workspace(name: name, path: path, isDefault: name == 'default');
  }

  /// Ensures the default workspace exists, creating it if necessary.
  Future<Workspace> ensureDefaultWorkspace() async {
    const defaultName = 'default';
    final path =
        '${_locator.workspacesPath}${Platform.pathSeparator}$defaultName';
    final dir = Directory(path);

    if (!await dir.exists()) {
      return createWorkspace(defaultName);
    }

    return Workspace(name: defaultName, path: path, isDefault: true);
  }

  Future<void> _createWorkspaceStructure(String path, String name) async {
    final sep = Platform.pathSeparator;
    // Create subdirectories
    for (final subdir in ['conversations', 'projects', 'resources', '.bricks']) {
      await Directory('$path$sep$subdir').create(recursive: true);
    }
    // Write workspace metadata
    final metaFile = File('$path${sep}.bricks${sep}workspace.yaml');
    await metaFile.writeAsString('name: $name\ncreated_at: ${DateTime.now().toIso8601String()}\n');
  }
}

/// Thrown when attempting to create a workspace that already exists.
class WorkspaceAlreadyExistsException implements Exception {
  WorkspaceAlreadyExistsException(this.name);
  final String name;

  @override
  String toString() => 'WorkspaceAlreadyExistsException: "$name" already exists.';
}
