import 'package:platform_bridge/src/io/platform_paths_io.dart';
import 'package:test/test.dart';

void main() {
  test('resolves mobile app data directory from iOS temp directory', () {
    final appDataDirectory = mobileAppDataDirectoryFromTempPath(
      '/private/var/mobile/Containers/Data/Application/APP-ID/tmp',
    );

    expect(
      appDataDirectory,
      '/private/var/mobile/Containers/Data/Application/APP-ID',
    );
  });

  test('resolves mobile app data directory from Android cache directory', () {
    final appDataDirectory = mobileAppDataDirectoryFromTempPath(
      '/data/user/0/dev.askman.bricks/cache',
    );

    expect(appDataDirectory, '/data/user/0/dev.askman.bricks');
  });
}
