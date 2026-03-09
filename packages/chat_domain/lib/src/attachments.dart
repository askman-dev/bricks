/// Describes an attachment that can be included in a chat message.
sealed class Attachment {
  const Attachment({required this.id, required this.name});
  final String id;
  final String name;

  /// Serialises this attachment to a JSON-compatible map.
  Map<String, Object?> toMap();

  /// Deserialises an [Attachment] from a JSON-compatible map.
  static Attachment fromMap(Map<String, Object?> map) {
    final type = map['type'] as String;
    return switch (type) {
      'file' => FileAttachment(
          id: map['id'] as String,
          name: map['name'] as String,
          path: map['path'] as String,
          mimeType: map['mime_type'] as String,
          sizeBytes: map['size_bytes'] as int,
        ),
      'resource' => ResourceAttachment(
          id: map['id'] as String,
          name: map['name'] as String,
          resourcePath: map['resource_path'] as String,
        ),
      _ => throw ArgumentError('Unknown attachment type: $type'),
    };
  }
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

  @override
  Map<String, Object?> toMap() => {
        'type': 'file',
        'id': id,
        'name': name,
        'path': path,
        'mime_type': mimeType,
        'size_bytes': sizeBytes,
      };
}

/// A reference to a workspace resource attached to a message.
final class ResourceAttachment extends Attachment {
  const ResourceAttachment({
    required super.id,
    required super.name,
    required this.resourcePath,
  });
  final String resourcePath;

  @override
  Map<String, Object?> toMap() => {
        'type': 'resource',
        'id': id,
        'name': name,
        'resource_path': resourcePath,
      };
}
