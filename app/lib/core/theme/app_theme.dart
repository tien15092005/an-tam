import 'package:flutter/material.dart';

import 'tokens.dart';

abstract final class AppTheme {
  static const fontFamily = 'BeVietnamPro';

  static ThemeData build(UiDensity density) {
    final scale = DensityScale.of(density);
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.navy,
      surface: AppColors.surface,
      error: AppColors.danger,
    );

    TextStyle text(double size, FontWeight weight, [Color color = AppColors.ink]) =>
        TextStyle(fontFamily: fontFamily, fontSize: size, fontWeight: weight, color: color, height: 1.35);

    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md));
    final buttonSize = Size.fromHeight(scale.minTouchTarget);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: fontFamily,
      textTheme: TextTheme(
        headlineMedium: text(scale.headline, FontWeight.w800),
        titleLarge: text(scale.title, FontWeight.w700),
        titleMedium: text(scale.body + 2, FontWeight.w600),
        bodyLarge: text(scale.body, FontWeight.w400),
        bodyMedium: text(scale.body - 1, FontWeight.w400, AppColors.muted),
        labelLarge: text(scale.body, FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        elevation: 0,
        titleTextStyle: text(scale.title * 0.9, FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: buttonSize, shape: buttonShape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          side: const BorderSide(color: AppColors.line, width: 1.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    );
  }
}
