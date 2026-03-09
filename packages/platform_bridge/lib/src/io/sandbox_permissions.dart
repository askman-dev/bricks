import '../sandbox_permissions.dart';

/// Native implementation of [SandboxPermissions].
///
/// On desktop platforms the app has full filesystem access by default.
/// On iOS/Android this class should be extended with the appropriate
/// permission-request plugin (e.g. `permission_handler`).
class IoSandboxPermissions implements SandboxPermissions {
  @override
  Future<bool> canRead(String path) async => true;

  @override
  Future<bool> canWrite(String path) async => true;

  @override
  Future<bool> requestAccess(String path) async => true;
}
