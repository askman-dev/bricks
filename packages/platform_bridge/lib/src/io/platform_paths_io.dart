import 'dart:io';

import '../platform_paths.dart';

/// Dart IO implementation of [PlatformPaths].
///
/// Resolves paths using [Platform.environment] on each supported OS.
/// Used on native (mobile/desktop) targets.
class PlatformPathsImpl implements PlatformPaths {
  @override
  Future<String> documentsDirectory() async {
    if (Platform.isMacOS || Platform.isLinux) {
      return '${Platform.environment['HOME']}/Documents';
    }
    if (Platform.isWindows) {
      return '${Platform.environment['USERPROFILE']}\\Documents';
    }
    throw UnsupportedError(
      'documentsDirectory is not supported on this platform.',
    );
  }

  @override
  Future<String> cacheDirectory() async {
    if (Platform.isMacOS) {
      return '${Platform.environment['HOME']}/Library/Caches/bricks';
    }
    if (Platform.isLinux) {
      return '${Platform.environment['HOME']}/.cache/bricks';
    }
    if (Platform.isWindows) {
      return '${Platform.environment['LOCALAPPDATA']}\\bricks\\cache';
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
}
