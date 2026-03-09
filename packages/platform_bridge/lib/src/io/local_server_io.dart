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
    final relativePath = request.uri.path.replaceFirst('/', '');
    final file = File('$_serveDirectory/$relativePath');
    if (await file.exists()) {
      request.response.statusCode = HttpStatus.ok;
      await file.openRead().pipe(request.response);
    } else {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
    }
  }
}
