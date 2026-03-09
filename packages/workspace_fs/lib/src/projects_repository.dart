import 'dart:io';
import 'path_validator.dart';

/// Manages project directories within a workspace.
class ProjectsRepository {
  ProjectsRepository({required String workspacePath})
      : _projectsPath = '$workspacePath${Platform.pathSeparator}projects';

  final String _projectsPath;

  /// Returns the names of all projects in the workspace.
  Future<List<String>> listProjectNames() async {
    final dir = Directory(_projectsPath);
    if (!await dir.exists()) return [];

    final names = <String>[];
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        names.add(entity.path.split(Platform.pathSeparator).last);
      }
    }
    return names;
  }

  /// Returns the absolute path for a project directory, creating it
  /// if [create] is true.
  ///
  /// Throws [ArgumentError] if [projectName] contains path separators or `..`.
  Future<String> projectPath(String projectName, {bool create = false}) async {
    PathValidator.validateSegment(projectName, 'projectName');
    final path = '$_projectsPath${Platform.pathSeparator}$projectName';
    if (create) {
      await Directory(path).create(recursive: true);
    }
    return path;
  }
}
