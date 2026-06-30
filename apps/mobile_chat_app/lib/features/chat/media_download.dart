import 'media_download_stub.dart'
    if (dart.library.html) 'media_download_web.dart' as impl;

Future<void> downloadChatMedia({
  required Uri uri,
  required String filename,
  required String? authToken,
}) {
  return impl.downloadChatMedia(
    uri: uri,
    filename: filename,
    authToken: authToken,
  );
}
