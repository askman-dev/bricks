import '../sandbox_permissions.dart';

/// Web stub implementation of [SandboxPermissions].
///
/// The Web platform does not use native sandbox permissions.
/// All permission checks return [true] so callers can proceed normally.
class WebSandboxPermissions implements SandboxPermissions {
  @override
  Future<bool> canRead(String path) async => true;

  @override
  Future<bool> canWrite(String path) async => true;

  @override
  Future<bool> requestAccess(String path) async => true;
}
