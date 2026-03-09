/// Requests and checks filesystem sandbox permissions.
///
/// On iOS and Android, the app must request permission before accessing
/// paths outside its sandbox. This interface abstracts those checks.
abstract interface class SandboxPermissions {
  /// Returns true if the app currently has read access to [path].
  Future<bool> canRead(String path);

  /// Returns true if the app currently has write access to [path].
  Future<bool> canWrite(String path);

  /// Requests read/write access to [path].
  ///
  /// Returns true if permission was granted.
  Future<bool> requestAccess(String path);
}
