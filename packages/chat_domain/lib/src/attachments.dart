/// Describes an attachment that can be included in a chat message.
sealed class Attachment {
  const Attachment({required this.id, required this.name});
  final String id;
  final String name;
}

/// A local file attached to a message.
final class FileAttachment extends Attachment {
  const FileAttachment({
    required super.id,
    required super.name,
    required this.path,
    required this.mimeType,
    required this.sizeBytes,
  });
  final String path;
  final String mimeType;
  final int sizeBytes;
}

/// A reference to a workspace resource attached to a message.
final class ResourceAttachment extends Attachment {
  const ResourceAttachment({
    required super.id,
    required super.name,
    required this.resourcePath,
  });
  final String resourcePath;
}
