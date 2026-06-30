// TODO(migrate): Switch from `dart:html` to `package:web` + `dart:js_interop`.
// ignore: deprecated_member_use
import 'dart:html' as html;

String _downloadFilename(String filename) {
  final trimmed = filename.trim();
  if (trimmed.isEmpty) return 'bricks-media';
  return trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}

Future<void> downloadChatMedia({
  required Uri uri,
  required String filename,
  required String? authToken,
}) async {
  final response = await html.HttpRequest.request(
    uri.toString(),
    method: 'GET',
    responseType: 'blob',
    requestHeaders: {
      if (authToken != null && authToken.isNotEmpty)
        'Authorization': 'Bearer $authToken',
    },
  );
  final blob = response.response;
  if (blob is! html.Blob) {
    throw StateError('Download response did not include a file.');
  }

  final objectUrl = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: objectUrl)
    ..download = _downloadFilename(filename)
    ..style.display = 'none';
  try {
    html.document.body?.append(anchor);
    anchor.click();
  } finally {
    anchor.remove();
    html.Url.revokeObjectUrl(objectUrl);
  }
}
