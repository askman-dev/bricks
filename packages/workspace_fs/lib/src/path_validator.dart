/// Shared path validation utilities for workspace filesystem operations.
class PathValidator {
  const PathValidator._();

  /// Throws [ArgumentError] if [value] is empty, contains `/` or `\`
  /// path separators, or equals `..` exactly.
  ///
  /// Both `/` and `\` are checked regardless of the current platform to
  /// prevent cross-platform path traversal attempts. The `..` check uses
  /// exact equality so names like `my..workspace` are still accepted.
  static void validateSegment(String value, String paramName) {
    if (value.isEmpty) {
      throw ArgumentError.value(
        value,
        paramName,
        '$paramName must not be empty',
      );
    }
    // Reject common path separators to guard against traversal.
    // Use exact equality for '..' rather than contains() to avoid rejecting
    // legitimate names like 'my..workspace'.
    if (value.contains('/') || value.contains('\\') || value == '..') {
      throw ArgumentError.value(
        value,
        paramName,
        '$paramName must not contain path separators or ".."',
      );
    }
  }
}
