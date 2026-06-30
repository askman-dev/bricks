Future<void> downloadChatMedia({
  required Uri uri,
  required String filename,
  required String? authToken,
}) async {
  throw UnsupportedError('Media download is only available in the web app.');
}
