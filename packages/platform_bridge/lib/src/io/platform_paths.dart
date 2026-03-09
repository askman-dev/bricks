import 'dart:io';

import '../platform_paths.dart';

/// Native (dart:io) implementation of [PlatformPaths].
///
/// Resolves platform-specific user and cache directories using
/// well-known conventions for each OS.
class IoPlatformPaths implements PlatformPaths {
  @override
  Future<String> documentsDirectory() async {
    if (Platform.isMacOS) {
      return '${Platform.environment['HOME']}/Documents';
    } else if (Platform.isLinux) {
      return Platform.environment['HOME'] ?? '/home';
    } else if (Platform.isWindows) {
      return Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Default';
    } else if (Platform.isIOS || Platform.isAndroid) {
      // On mobile the documents directory is the app sandbox root.
      return Platform.environment['HOME'] ?? '/';
    }
    return Platform.environment['HOME'] ?? '/';
  }

  @override
  Future<String> cacheDirectory() async {
    if (Platform.isMacOS) {
      return '${Platform.environment['HOME']}/Library/Caches';
    } else if (Platform.isLinux) {
      return '${Platform.environment['HOME']}/.cache';
    } else if (Platform.isWindows) {
      return '${Platform.environment['LOCALAPPDATA']}\\cache';
    }
    return '${Platform.environment['HOME']}/.cache';
  }

  @override
  Future<String> bricksRootDirectory() async {
    final docs = await documentsDirectory();
    return '$docs${Platform.pathSeparator}Bricks';
  }
}
