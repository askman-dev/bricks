/// Resolves platform-specific sandbox and document paths.
///
/// Each platform (iOS, Android, macOS, Windows, Linux) stores documents
/// in a different location. [PlatformPaths] abstracts these differences.
abstract interface class PlatformPaths {
  /// Returns the absolute path to the app's documents directory.
  Future<String> documentsDirectory();

  /// Returns the absolute path to the app's cache directory.
  Future<String> cacheDirectory();

  /// Returns the absolute path used as the Bricks root directory.
  Future<String> bricksRootDirectory();
}
