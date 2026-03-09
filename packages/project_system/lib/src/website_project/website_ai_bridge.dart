/// Bridge between a website project and the AI agent.
///
/// Exposes project file content for context injection and provides
/// file update capabilities for AI-driven edits.
class WebsiteAiBridge {
  const WebsiteAiBridge({required String projectPath})
      : _projectPath = projectPath;

  final String _projectPath;

  /// The root path of the project this bridge is attached to.
  String get projectPath => _projectPath;

  // TODO(project_system): implement file read/write methods for AI context
  // injection and AI-driven project edits.
}
