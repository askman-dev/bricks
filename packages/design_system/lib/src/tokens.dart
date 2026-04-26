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

/// Centralized app color palette with semantic names.
///
/// The dark palette follows a near-black foundation (#212121) + grayscale surfaces +
/// single brand blue accent strategy.
class AppColors {
  const AppColors._();

  // Backgrounds
  static const backgroundBase = Color(0xFF212121);
  static const backgroundChrome = Color(0xFF000000);

  // Surfaces
  static const surfaceDefault = Color(0xFF16181C);
  static const surfaceElevated = Color(0xFF1C1F23);
  static const surfaceSubtle = Color(0xFF202327);
  static const surfaceInput = Color(0xFF303030);

  // Borders
  static const borderSubtle = Color(0xFF2F3336);
  static const borderFocus = Color(0xFF536471);

  // Typography
  static const textPrimary = Color(0xFFE7E9EA);
  static const textSecondary = Color(0xFF71767B);
  static const textTertiary = Color(0xFF536471);

  // Accent
  static const accentPrimary = Color(0xFF1D9BF0);
  static const accentMuted = Color(0xFF0A3A5C);

  // Status colors
  static const danger = Color(0xFFF4212E);
  static const warning = Color(0xFFFFD400);
  static const success = Color(0xFF00BA7C);

  // ------------------------------------------------------------------------
  // Legacy aliases kept for compatibility with existing components.
  // ------------------------------------------------------------------------
  static const background = backgroundBase;
  static const surface = surfaceDefault;
  static const surface2 = surfaceElevated;
  static const surface3 = surfaceSubtle;
  static const border = borderSubtle;
  static const divider = borderFocus;
  static const iconPrimary = textPrimary;
  static const iconSecondary = textSecondary;
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
