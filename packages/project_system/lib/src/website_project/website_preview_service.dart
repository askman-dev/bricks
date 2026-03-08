/// Provides a preview URL for a website project via the local server.
///
/// The actual local HTTP server is managed by `platform_bridge`.
/// This service only resolves the preview URL given the project entry point.
class WebsitePreviewService {
  const WebsitePreviewService({this.localServerPort = 7474});

  final int localServerPort;

  /// Returns the preview URL for the project's [entryPoint].
  Uri previewUrl(String projectName, {String entryPoint = 'index.html'}) {
    return Uri.parse(
      'http://localhost:$localServerPort/$projectName/$entryPoint',
    );
  }
}
