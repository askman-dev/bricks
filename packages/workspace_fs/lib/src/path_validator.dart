import 'dart:io';

/// Shared path validation utilities for workspace filesystem operations.
class PathValidator {
  const PathValidator._();

  /// Throws [ArgumentError] if [value] is empty, contains path separators,
  /// or contains `..`.
  ///
  /// Checks both the platform-specific separator and the POSIX `/` separator
  /// to guard against cross-platform path traversal attempts.
  static void validateSegment(String value, String paramName) {
    if (value.isEmpty) {
      throw ArgumentError.value(
        value,
        paramName,
        '$paramName must not be empty',
      );
    }
    // Reject the platform separator and POSIX '/' to guard against traversal.
    // Use exact equality for '..' rather than contains() to avoid rejecting
    // legitimate names like 'my..workspace'.
    if (value.contains('/') ||
        value.contains(Platform.pathSeparator) ||
        value == '..') {
      throw ArgumentError.value(
        value,
        paramName,
        '$paramName must not contain path separators or ".."',
      );
    }
  }
}
