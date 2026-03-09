/// Cross-platform bridge for Bricks.
///
/// Provides filesystem permissions, sandbox paths, local server,
/// WebView/browser runtime integration, and device-level abstractions
/// across iOS, Android, desktop, and web.
library platform_bridge;

// Abstract interfaces (always exported).
export 'src/local_server.dart';
export 'src/platform_paths.dart';
export 'src/sandbox_permissions.dart';

// Concrete implementations – Web stubs are used when dart:html is available;
// otherwise the dart:io backed implementations are used.
export 'src/io/local_server.dart'
    if (dart.library.html) 'src/web/local_server.dart';
export 'src/io/platform_paths.dart'
    if (dart.library.html) 'src/web/platform_paths.dart';
export 'src/io/sandbox_permissions.dart'
    if (dart.library.html) 'src/web/sandbox_permissions.dart';
