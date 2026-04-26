import 'package:flutter/widgets.dart';

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

/// A centralized color palette matching the design target.
class AppColors {
  const AppColors._();

  static const background = Color(0xFF000000);

  static const surface = Color(0xFF111111);
  static const surface2 = Color(0xFF1C1C1E);
  static const surface3 = Color(0xFF232325);

  static const border = Color(0xFF2C2C2E);
  static const divider = Color(0xFF3A3A3C);

  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFF9A9AA0);
  static const textTertiary = Color(0xFF6C6C70);

  static const iconPrimary = Color(0xFFF5F5F7);
  static const iconSecondary = Color(0xFFB0B0B5);

  static const danger = Color(0xFF8B8B90);
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
