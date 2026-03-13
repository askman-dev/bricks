import '../platform_paths.dart';

/// Web stub implementation of [PlatformPaths].
///
/// The Web platform has no local filesystem, so all paths return an
/// empty string. Agent definitions are persisted via IndexedDB instead
/// of a filesystem path.
class PlatformPathsImpl implements PlatformPaths {
  @override
  Future<String> documentsDirectory() => Future.value('');

  @override
  Future<String> cacheDirectory() => Future.value('');

  @override
  Future<String> bricksRootDirectory() => Future.value('');

  @override
  Future<String> agentsDirectory() => Future.value('');
}
