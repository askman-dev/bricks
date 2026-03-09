/// Cross-platform bridge for Bricks.
///
/// Provides filesystem permissions, sandbox paths, local server,
/// WebView/browser runtime integration, and device-level abstractions
/// across iOS, Android, desktop, and web.
library platform_bridge;

// Abstract interfaces
export 'src/local_server.dart';
export 'src/platform_paths.dart';
export 'src/sandbox_permissions.dart';

// Concrete implementations – IO for native targets, Web stubs for browser.
export 'src/io/local_server_io.dart'
    if (dart.library.html) 'src/web/local_server_web.dart';
export 'src/io/platform_paths_io.dart'
    if (dart.library.html) 'src/web/platform_paths_web.dart';
export 'src/io/sandbox_permissions_io.dart'
    if (dart.library.html) 'src/web/sandbox_permissions_web.dart';
