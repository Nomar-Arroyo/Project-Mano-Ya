import 'package:flutter/material.dart';

import '../constants/colors.dart';
import 'app_spacing.dart';

class AppTheme {
  static ThemeData light() => _buildTheme(
    brightness: Brightness.light,
    scheme:
        ColorScheme.fromSeed(
          seedColor: ManoYaColors.primary,
          brightness: Brightness.light,
          primary: ManoYaColors.primary,
          onPrimary: Colors.white,
          secondary: ManoYaColors.secondary,
          onSecondary: Colors.white,
          surface: ManoYaColors.background,
          onSurface: ManoYaColors.textPrimary,
          error: ManoYaColors.danger,
        ).copyWith(
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: ManoYaColors.surfaceContainer,
          surfaceContainer: const Color(0xFFEAEDFF),
          surfaceContainerHigh: const Color(0xFFE2E7FF),
          outline: ManoYaColors.muted,
          outlineVariant: ManoYaColors.border,
        ),
    background: ManoYaColors.background,
    surface: ManoYaColors.background,
    onSurface: ManoYaColors.textPrimary,
    muted: ManoYaColors.muted,
    outline: ManoYaColors.border,
    fieldFill: ManoYaColors.surfaceContainer,
  );

  static ThemeData dark() => _buildTheme(
    brightness: Brightness.dark,
    scheme:
        ColorScheme.fromSeed(
          seedColor: ManoYaColors.primaryLight,
          brightness: Brightness.dark,
          primary: const Color(0xFF78A6FF),
          onPrimary: ManoYaColors.darkBackground,
          secondary: const Color(0xFFFF9A52),
          onSecondary: ManoYaColors.darkBackground,
          surface: ManoYaColors.darkSurface,
          onSurface: ManoYaColors.darkTextPrimary,
          error: const Color(0xFFFF8A80),
        ).copyWith(
          surfaceContainerLowest: ManoYaColors.darkBackground,
          surfaceContainerLow: ManoYaColors.darkSurface,
          surfaceContainer: const Color(0xFF1B273B),
          surfaceContainerHigh: const Color(0xFF243149),
          outline: const Color(0xFF9AA7BC),
          outlineVariant: ManoYaColors.darkBorder,
        ),
    background: ManoYaColors.darkBackground,
    surface: ManoYaColors.darkSurface,
    onSurface: ManoYaColors.darkTextPrimary,
    muted: const Color(0xFFAAB5C6),
    outline: ManoYaColors.darkBorder,
    fieldFill: const Color(0xFF1B273B),
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color background,
    required Color surface,
    required Color onSurface,
    required Color muted,
    required Color outline,
    required Color fieldFill,
  }) {
    final isDark = brightness == Brightness.dark;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    final textTheme = ThemeData(brightness: brightness, useMaterial3: true)
        .textTheme
        .copyWith(
          displayLarge: TextStyle(
            color: onSurface,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.64,
            height: 1.2,
          ),
          headlineLarge: TextStyle(
            color: onSurface,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.39,
            height: 1.28,
          ),
          headlineMedium: TextStyle(
            color: onSurface,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.22,
            height: 1.28,
          ),
          titleLarge: TextStyle(
            color: onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.18,
          ),
          titleMedium: TextStyle(
            color: onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(color: onSurface, fontSize: 16, height: 1.5),
          bodyMedium: TextStyle(color: onSurface, fontSize: 14, height: 1.45),
          bodySmall: TextStyle(color: muted, fontSize: 12, height: 1.4),
          labelLarge: TextStyle(
            color: onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: isDark ? ManoYaColors.darkSurface : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: isDark ? 0 : 1,
        shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.06),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: outline.withValues(alpha: isDark ? 0.7 : 0.55),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: shape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: shape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: BorderSide(color: outline),
          shape: shape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: _inputDecorationTheme(
        scheme: scheme,
        fieldFill: fieldFill,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.08),
        indicatorColor: scheme.primary.withValues(alpha: 0.10),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : muted,
            size: selected ? 23 : 21,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? scheme.primary : muted,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.1,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: fieldFill,
        selectedColor: scheme.primary,
        disabledColor: fieldFill.withValues(alpha: 0.6),
        labelStyle: textTheme.labelMedium,
        side: BorderSide(color: outline.withValues(alpha: 0.55)),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        showCheckmark: false,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return muted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return ManoYaColors.success;
          }
          return outline.withValues(alpha: 0.25);
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: ManoYaColors.secondary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF293548)
            : const Color(0xFF283044),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        insetPadding: const EdgeInsets.all(16),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: outline.withValues(alpha: 0.65),
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primary.withValues(alpha: 0.12),
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  static InputDecorationTheme _inputDecorationTheme({
    required ColorScheme scheme,
    required Color fieldFill,
  }) {
    final radius = BorderRadius.circular(AppRadius.sm);
    return InputDecorationTheme(
      filled: true,
      fillColor: fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.error, width: 1.6),
      ),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
    );
  }
}
