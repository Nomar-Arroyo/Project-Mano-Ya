import 'package:flutter/material.dart';

import '../constants/colors.dart';

// Tema central de la aplicación: expone las variantes clara y oscura
// compartiendo los estilos de botones e inputs.
class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ManoYaColors.primary,
        primary: ManoYaColors.primary,
        secondary: ManoYaColors.secondary,
        surface: ManoYaColors.surface,
      ),
      scaffoldBackgroundColor: ManoYaColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: ManoYaColors.surface,
        foregroundColor: ManoYaColors.textPrimary,
        elevation: 0,
      ),
      elevatedButtonTheme: _elevatedButtonTheme(),
      inputDecorationTheme: _inputDecorationTheme(),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ManoYaColors.primary,
        brightness: Brightness.dark,
        primary: ManoYaColors.primary,
        secondary: ManoYaColors.secondary,
        surface: ManoYaColors.darkSurface,
      ),
      scaffoldBackgroundColor: ManoYaColors.darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: ManoYaColors.darkSurface,
        foregroundColor: ManoYaColors.darkTextPrimary,
        elevation: 0,
      ),
      elevatedButtonTheme: _elevatedButtonTheme(),
      inputDecorationTheme: _inputDecorationTheme(),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ManoYaColors.secondary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme() {
    return InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }
}
