import 'dart:io';

/// Manages resource directories within a workspace.
class ResourcesRepository {
  ResourcesRepository({required String workspacePath})
      : _resourcesPath = '$workspacePath${Platform.pathSeparator}resources';

  final String _resourcesPath;

  /// Returns the names of all resource files in the workspace.
  Future<List<String>> listResourceNames() async {
    final dir = Directory(_resourcesPath);
    if (!await dir.exists()) return [];

    final names = <String>[];
    await for (final entity in dir.list()) {
      if (entity is File) {
        names.add(entity.path.split(Platform.pathSeparator).last);
      }
    }
    return names;
  }

  /// Returns the absolute path for the resources directory.
  String get resourcesPath => _resourcesPath;
}
