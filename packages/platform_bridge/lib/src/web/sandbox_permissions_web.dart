import '../sandbox_permissions.dart';

/// Web stub implementation of [SandboxPermissions].
///
/// The Web platform has no native sandbox permission model, so all
/// access checks return [true].
class SandboxPermissionsImpl implements SandboxPermissions {
  @override
  Future<bool> canRead(String path) => Future.value(true);

  @override
  Future<bool> canWrite(String path) => Future.value(true);

  @override
  Future<bool> requestAccess(String path) => Future.value(true);
}
