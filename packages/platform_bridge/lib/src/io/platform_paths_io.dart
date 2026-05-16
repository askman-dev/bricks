import 'dart:io';

import '../platform_paths.dart';

/// Dart IO implementation of [PlatformPaths].
///
/// Resolves paths using [Platform.environment] on each supported OS.
/// Used on native (mobile/desktop) targets.
class PlatformPathsImpl implements PlatformPaths {
  String _requiredEnv(String name) {
    final value = Platform.environment[name];
    if (value == null || value.isEmpty) {
      throw UnsupportedError(
        '$name environment variable is not available on this platform.',
      );
    }
    return value;
  }

  String _androidAppDataDirectory() {
    final cacheDir = Directory.systemTemp;
    final appDataDir = cacheDir.parent;
    return appDataDir.path;
  }

  @override
  Future<String> documentsDirectory() async {
    if (Platform.isMacOS || Platform.isLinux) {
      return '${_requiredEnv('HOME')}/Documents';
    }
    if (Platform.isWindows) {
      return '${_requiredEnv('USERPROFILE')}\\Documents';
    }
    if (Platform.isIOS) {
      return '${_requiredEnv('HOME')}/Documents';
    }
    if (Platform.isAndroid) {
      return '${_androidAppDataDirectory()}/files';
    }
    throw UnsupportedError(
      'documentsDirectory is not supported on this platform.',
    );
  }

  @override
  Future<String> cacheDirectory() async {
    if (Platform.isMacOS) {
      return '${_requiredEnv('HOME')}/Library/Caches/bricks';
    }
    if (Platform.isLinux) {
      return '${_requiredEnv('HOME')}/.cache/bricks';
    }
    if (Platform.isWindows) {
      return '${_requiredEnv('LOCALAPPDATA')}\\bricks\\cache';
    }
    if (Platform.isIOS) {
      return '${_requiredEnv('HOME')}/Library/Caches/bricks';
    }
    if (Platform.isAndroid) {
      return '${_androidAppDataDirectory()}/cache/bricks';
    }
    throw UnsupportedError(
      'cacheDirectory is not supported on this platform.',
    );
  }

  @override
  Future<String> bricksRootDirectory() async {
    final docs = await documentsDirectory();
    return '$docs/Bricks';
  }

  @override
  Future<String> agentsDirectory() async {
    if (Platform.isMacOS) {
      return '${_requiredEnv('HOME')}/Library/Application Support/bricks/agents';
    }
    if (Platform.isLinux) {
      return '${_requiredEnv('HOME')}/.local/share/bricks/agents';
    }
    if (Platform.isWindows) {
      return '${_requiredEnv('LOCALAPPDATA')}\\bricks\\agents';
    }
    if (Platform.isIOS) {
      return '${_requiredEnv('HOME')}/Library/Application Support/bricks/agents';
    }
    if (Platform.isAndroid) {
      return '${_androidAppDataDirectory()}/files/bricks/agents';
    }
    throw UnsupportedError(
      'agentsDirectory is not supported on this platform.',
    );
  }
}
