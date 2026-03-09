import '../local_server.dart';

/// Web stub implementation of [LocalServer].
///
/// The Web platform cannot host a native HTTP server, so this stub
/// returns immediately from [start] and exposes a placeholder [previewUrl].
class WebLocalServer implements LocalServer {
  @override
  int get port => 0;

  @override
  bool get isRunning => false;

  @override
  Future<void> start({required String serveDirectory}) => Future.value();

  @override
  Future<void> stop() => Future.value();

  @override
  Uri previewUrl(String projectName, {String entryPoint = 'index.html'}) {
    return Uri.parse('https://preview.bricks.dev/$projectName/$entryPoint');
  }
}
