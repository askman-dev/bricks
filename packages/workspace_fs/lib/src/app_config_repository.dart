import 'dart:io';

/// Loads and provides the merged app configuration.
///
/// Config is read from `<root>/config.yaml` (global) and
/// `<workspace>/.bricks/config.yaml` (workspace-level override).
class AppConfigRepository {
  AppConfigRepository({
    required String rootPath,
    String? workspacePath,
  })  : _globalConfigPath = '$rootPath${Platform.pathSeparator}config.yaml',
        _workspaceConfigPath = workspacePath != null
            ? '$workspacePath${Platform.pathSeparator}.bricks${Platform.pathSeparator}config.yaml'
            : null;

  final String _globalConfigPath;
  final String? _workspaceConfigPath;

  /// Returns the raw YAML content of the global config, or null if absent.
  Future<String?> loadGlobalConfig() async {
    final file = File(_globalConfigPath);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  /// Returns the raw YAML content of the workspace config, or null if absent.
  Future<String?> loadWorkspaceConfig() async {
    if (_workspaceConfigPath == null) return null;
    final file = File(_workspaceConfigPath!);
    if (!await file.exists()) return null;
    return file.readAsString();
  }
}
