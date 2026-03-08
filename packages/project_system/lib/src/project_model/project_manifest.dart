import 'project_type.dart';

/// The contents of a `bricks.project.yaml` manifest file.
class ProjectManifest {
  const ProjectManifest({
    required this.name,
    required this.type,
    this.description,
    this.entryPoint = 'index.html',
    this.version = '0.1.0',
  });

  final String name;
  final ProjectType type;
  final String? description;

  /// The entry-point file for preview (relative to project root).
  final String entryPoint;

  final String version;

  /// Serialises to a YAML-compatible map.
  Map<String, Object?> toMap() => {
        'name': name,
        'type': type.name,
        'description': description,
        'entry_point': entryPoint,
        'version': version,
      };

  /// Deserialises from a YAML-compatible map.
  factory ProjectManifest.fromMap(Map<String, Object?> map) {
    return ProjectManifest(
      name: map['name'] as String,
      type: ProjectType.values.byName(map['type'] as String),
      description: map['description'] as String?,
      entryPoint: (map['entry_point'] as String?) ?? 'index.html',
      version: (map['version'] as String?) ?? '0.1.0',
    );
  }
}
