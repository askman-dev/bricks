import 'project_manifest.dart';
import 'project_type.dart';

/// Represents a Bricks project residing at [path].
class Project {
  const Project({
    required this.name,
    required this.path,
    required this.type,
    required this.manifest,
    this.createdAt,
    this.updatedAt,
  });

  final String name;
  final String path;
  final ProjectType type;
  final ProjectManifest manifest;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  @override
  String toString() => 'Project(name: $name, type: $type, path: $path)';
}
