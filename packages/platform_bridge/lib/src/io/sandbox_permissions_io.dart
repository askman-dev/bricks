import 'dart:io';

import '../sandbox_permissions.dart';

/// Dart IO implementation of [SandboxPermissions].
///
/// Probes read/write access by attempting filesystem operations.
/// On platforms without sandboxing (desktop/Linux/Windows) access is
/// generally always granted; on iOS/Android the OS mediates permissions
/// outside of this package.
class SandboxPermissionsImpl implements SandboxPermissions {
  @override
  Future<bool> canRead(String path) async {
    try {
      await Directory(path).list().take(1).drain();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> canWrite(String path) async {
    final probe = File('$path/.bricks_write_probe_${DateTime.now().microsecondsSinceEpoch}');
    try {
      await probe.create(recursive: true);
      await probe.delete();
      return true;
    } catch (_) {
      // Best-effort cleanup in case the file was created but delete failed.
      try {
        await probe.delete();
      } catch (_) {}
      return false;
    }
  }

  @override
  Future<bool> requestAccess(String path) async {
    // On non-sandboxed native platforms, access is always available.
    return true;
  }
}
