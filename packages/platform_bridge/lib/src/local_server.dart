/// Controls the local HTTP server used to preview website projects.
///
/// The server serves files from the configured [serveDirectory] and
/// is used by the WebView to load project previews.
abstract interface class LocalServer {
  /// The port the server is (or will be) listening on.
  int get port;

  /// Whether the server is currently running.
  bool get isRunning;

  /// Starts the server, serving files from [serveDirectory].
  Future<void> start({required String serveDirectory});

  /// Stops the server and releases the port.
  Future<void> stop();

  /// Returns the base URL for previewing a project.
  Uri previewUrl(String projectName, {String entryPoint = 'index.html'});
}
