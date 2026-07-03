class ComposerPastedImage {
  const ComposerPastedImage({
    required this.filename,
    required this.mimeType,
    required this.dataBase64,
  });

  final String filename;
  final String mimeType;
  final String dataBase64;
}

abstract class ComposerPasteImageSubscription {
  void cancel();
}
