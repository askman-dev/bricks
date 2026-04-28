// Flutter dependency – intentionally thin.
// ignore: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'chat_colors.dart';
import 'tokens.dart';

/// Provides the Bricks [ThemeData] for light and dark modes.
class BricksTheme {
  const BricksTheme._();

  /// Shared popup menu motion tuned for quick iOS-like scale/fade behavior.
  static const AnimationStyle menuPopupAnimationStyle = AnimationStyle(
    duration: Duration(milliseconds: 120),
    reverseDuration: Duration(milliseconds: 90),
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          foregroundColor: Color(0xFF1F2328),
          surfaceTintColor: Colors.transparent,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accentPrimary,
          brightness: Brightness.light,
        ).copyWith(
          surface: const Color(0xFFFFFFFF),
        ),
        extensions: const [ChatColors.light],
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.backgroundBase,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.backgroundChrome,
          foregroundColor: AppColors.textPrimary,
          surfaceTintColor: Colors.transparent,
        ),
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accentPrimary,
          onPrimary: AppColors.textPrimary,
          surface: AppColors.surfaceDefault,
          surfaceContainerHighest: AppColors.surfaceElevated,
          onSurface: AppColors.textPrimary,
          onSurfaceVariant: AppColors.textSecondary,
          outline: AppColors.borderSubtle,
          error: AppColors.danger,
        ),
        extensions: const [ChatColors.dark],
      );
}
