import 'dart:io';

import '../local_server.dart';

/// Dart IO implementation of [LocalServer].
///
/// Starts a minimal HTTP server that serves static files from the
/// configured [serveDirectory].  Used on native (mobile/desktop) targets.
class LocalServerImpl implements LocalServer {
  /// The initial preferred port; the actual bound port is stored in [port].
  final int _preferredPort;
  HttpServer? _httpServer;
  String _serveDirectory = '';
  int _boundPort;

  LocalServerImpl({int port = 7474})
      : _preferredPort = port,
        _boundPort = port;

  @override
  int get port => _boundPort;

  @override
  bool get isRunning => _httpServer != null;

  @override
  Future<void> start({required String serveDirectory}) async {
    _serveDirectory = serveDirectory;
    _httpServer =
        await HttpServer.bind(InternetAddress.loopbackIPv4, _preferredPort);
    _boundPort = _httpServer!.port;
    _httpServer!.listen(_handleRequest);
  }

  @override
  Future<void> stop() async {
    await _httpServer?.close(force: true);
    _httpServer = null;
  }

  @override
  Uri previewUrl(String projectName, {String entryPoint = 'index.html'}) {
    return Uri.parse('http://localhost:$_boundPort/$projectName/$entryPoint');
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final requestedPath = request.uri.path;
      // Break the path into non-empty segments and reject any traversal attempts.
      final segments =
          requestedPath.split('/').where((segment) => segment.isNotEmpty).toList();
      if (segments.any((segment) => segment == '..')) {
        request.response
          ..statusCode = HttpStatus.forbidden
          ..close();
        return;
      }

      // Rebuild a normalized relative path using the platform-specific separator.
      final normalizedRelativePath = segments.join(Platform.pathSeparator);

      // Resolve the requested path against the absolute serve directory.
      final baseDirectory = Directory(_serveDirectory).absolute;
      final baseUri = baseDirectory.uri;
      final resolvedUri = baseUri.resolve(normalizedRelativePath);
      final resolvedPath = File.fromUri(resolvedUri).path;

      // Ensure the resolved path is still within the serve directory.
      if (!_isWithinDirectory(baseDirectory.path, resolvedPath)) {
        request.response
          ..statusCode = HttpStatus.forbidden
          ..close();
        return;
      }

      final file = File(resolvedPath);
      if (await file.exists()) {
        request.response.statusCode = HttpStatus.ok;
        await file.openRead().pipe(request.response);
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..close();
      }
    } catch (_) {
      // In case of unexpected errors, return a generic server error.
      // Close the response with an error status.
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..close();
    }
  }

  /// Returns true if [targetPath] is the same as, or is contained within, [baseDir].
  bool _isWithinDirectory(String baseDir, String targetPath) {
    final base = Directory(baseDir).absolute.path;
    final target = File(targetPath).absolute.path;
    final normalizedBase =
        base.endsWith(Platform.pathSeparator) ? base : '$base${Platform.pathSeparator}';
    return target == base || target.startsWith(normalizedBase);
  }
}
