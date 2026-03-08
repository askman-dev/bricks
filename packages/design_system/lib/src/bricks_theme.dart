// Flutter dependency – intentionally thin.
// ignore: depend_on_referenced_packages
import 'package:flutter/material.dart';

/// Provides the Bricks [ThemeData] for light and dark modes.
class BricksTheme {
  const BricksTheme._();

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF4A90D9),
        brightness: Brightness.light,
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF4A90D9),
        brightness: Brightness.dark,
      );
}
