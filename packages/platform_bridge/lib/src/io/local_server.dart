import 'dart:io';

import '../local_server.dart';

/// Native (dart:io) implementation of [LocalServer].
///
/// Binds an [HttpServer] on the loopback interface and serves static files
/// from the configured [serveDirectory].
class IoLocalServer implements LocalServer {
  IoLocalServer({int port = 8080}) : _port = port;

  int _port;
  bool _isRunning = false;
  HttpServer? _server;

  @override
  int get port => _port;

  @override
  bool get isRunning => _isRunning;

  @override
  Future<void> start({required String serveDirectory}) async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);
    _port = _server!.port;
    _isRunning = true;
    _serve(serveDirectory);
  }

  void _serve(String serveDirectory) {
    _server?.listen((request) async {
      final filePath = '$serveDirectory${request.uri.path}'
          .replaceAll('/', Platform.pathSeparator);
      final file = File(filePath);
      if (await file.exists()) {
        request.response.headers.contentType =
            ContentType.parse(_mimeType(filePath));
        await request.response.addStream(file.openRead());
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });
  }

  String _mimeType(String path) {
    if (path.endsWith('.html')) return 'text/html';
    if (path.endsWith('.css')) return 'text/css';
    if (path.endsWith('.js')) return 'application/javascript';
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
    if (path.endsWith('.svg')) return 'image/svg+xml';
    return 'application/octet-stream';
  }

  @override
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
  }

  @override
  Uri previewUrl(String projectName, {String entryPoint = 'index.html'}) {
    return Uri.http('localhost:$_port', '/$projectName/$entryPoint');
  }
}
