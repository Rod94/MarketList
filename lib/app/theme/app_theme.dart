import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static final light = _build(Brightness.light);
  static final amoled = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = isDark
        ? AppColors.amoledBackground
        : AppColors.lightBackground;
    final text = isDark ? AppColors.amoledText : AppColors.lightText;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: isDark ? AppColors.amoledAccent : AppColors.lightAccent,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? AppColors.amoledAccent : AppColors.lightAccent,
          onPrimary: isDark
              ? AppColors.amoledBackground
              : AppColors.lightBackground,
          surface: background,
          onSurface: text,
          onSurfaceVariant: isDark
              ? AppColors.amoledSecondaryText
              : AppColors.lightSecondaryText,
          surfaceContainer: isDark
              ? AppColors.amoledSurface
              : AppColors.lightSurface,
          outlineVariant: isDark
              ? AppColors.amoledDivider
              : AppColors.lightDivider,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      dividerColor: scheme.outlineVariant,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
