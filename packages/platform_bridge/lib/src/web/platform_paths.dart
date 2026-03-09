import '../platform_paths.dart';

/// Web stub implementation of [PlatformPaths].
///
/// The Web platform has no native filesystem, so all paths return
/// empty strings to signal that filesystem operations are unavailable.
class WebPlatformPaths implements PlatformPaths {
  @override
  Future<String> documentsDirectory() async => '';

  @override
  Future<String> cacheDirectory() async => '';

  @override
  Future<String> bricksRootDirectory() async => '';
}
