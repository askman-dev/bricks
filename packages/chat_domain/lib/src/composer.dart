/// Mutable state model for the chat input composer.
class ComposerState {
  ComposerState({
    this.text = '',
    List<String>? attachedResourcePaths,
  }) : attachedResourcePaths = attachedResourcePaths ?? [];

  String text;
  final List<String> attachedResourcePaths;

  bool get isEmpty => text.trim().isEmpty && attachedResourcePaths.isEmpty;

  /// Resets the composer to its empty state.
  void clear() {
    text = '';
    attachedResourcePaths.clear();
  }
}
