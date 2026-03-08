/// A point-in-time snapshot of a project's files.
///
/// Used for undo/redo, version history, and recovery.
class ProjectSnapshot {
  const ProjectSnapshot({
    required this.id,
    required this.projectName,
    required this.createdAt,
    required this.files,
    this.label,
  });

  final String id;
  final String projectName;
  final DateTime createdAt;
  final String? label;

  /// Map of relative file path → file contents.
  final Map<String, String> files;
}
