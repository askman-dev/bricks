/// Design tokens: spacing, radius, and animation durations.
class BricksSpacing {
  const BricksSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

/// Semantic color names used across the app.
///
/// Actual color values are resolved from the active [BricksTheme].
class BricksColorTokens {
  const BricksColorTokens._();

  static const String surface = 'surface';
  static const String onSurface = 'onSurface';
  static const String primary = 'primary';
  static const String onPrimary = 'onPrimary';
  static const String error = 'error';
  static const String onError = 'onError';
}

/// Border radius tokens.
class BricksRadius {
  const BricksRadius._();

  static const double sm = 4.0;
  static const double md = 8.0;
  static const double lg = 16.0;
  static const double full = 999.0;
}

/// Animation duration tokens.
class BricksDuration {
  const BricksDuration._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
}
