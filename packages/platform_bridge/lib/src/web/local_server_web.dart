import '../local_server.dart';

/// Web stub implementation of [LocalServer].
///
/// The Web platform cannot run a local TCP server, so all operations
/// are no-ops and [previewUrl] returns a same-origin relative URL.
class LocalServerImpl implements LocalServer {
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
    return Uri.parse('/$projectName/$entryPoint');
  }
}
