import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

abstract final class AppTheme {
  /// Lexend (SIL Open Font License, assets/fonts/OFL.txt): designed for easy reading, full Vietnamese.
  static const fontFamily = 'Lexend';

  /// Builds the light or dark theme, whichever [AppColors.dark] says.
  static ThemeData build(UiDensity density) {
    final scale = DensityScale.of(density);
    final dark = AppColors.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: dark ? Brightness.dark : Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.onAccent,
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: AppColors.ink,
      secondary: AppColors.primary,
      onSecondary: AppColors.onAccent,
      secondaryContainer: AppColors.primarySoft,
      onSecondaryContainer: AppColors.ink,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surface,
      outline: AppColors.line,
      outlineVariant: AppColors.line,
      error: AppColors.danger,
      onError: AppColors.onAccent,
    );

    TextStyle text(double size, FontWeight weight, [Color? color]) => TextStyle(
        fontFamily: fontFamily, fontSize: size, fontWeight: weight, color: color ?? AppColors.ink, height: 1.35);

    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md));
    final buttonSize = Size.fromHeight(scale.minTouchTarget);
    final buttonText = text(scale.body, FontWeight.w600);

    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      fontFamily: fontFamily,
      dividerColor: AppColors.line,
      textTheme: TextTheme(
        displaySmall: text(scale.headline * 1.35, FontWeight.w700),
        headlineMedium: text(scale.headline, FontWeight.w700),
        headlineSmall: text(scale.headline * 0.85, FontWeight.w700),
        titleLarge: text(scale.title, FontWeight.w700),
        titleMedium: text(scale.body + 2, FontWeight.w600),
        titleSmall: text(scale.body + 1, FontWeight.w600),
        bodyLarge: text(scale.body, FontWeight.w400),
        bodyMedium: text(scale.body - 1, FontWeight.w400, AppColors.muted),
        bodySmall: text(scale.body - 2, FontWeight.w400, AppColors.muted),
        labelLarge: text(scale.body, FontWeight.w600),
        labelMedium: text(scale.body - 2, FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: text(scale.title * 0.95, FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      listTileTheme: ListTileThemeData(iconColor: AppColors.muted, textColor: AppColors.ink),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: buttonText,
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onAccent,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: buttonText,
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.surface,
          side: BorderSide(color: AppColors.line, width: 1.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary, textStyle: buttonText),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onAccent,
        extendedTextStyle: buttonText,
        shape: const StadiumBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primarySoft,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => text(
            12.5, s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            s.contains(WidgetState.selected) ? AppColors.primary : AppColors.muted)),
        iconTheme: WidgetStateProperty.resolveWith((s) =>
            IconThemeData(color: s.contains(WidgetState.selected) ? AppColors.primary : AppColors.muted)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      ),
      dialogTheme: DialogThemeData(backgroundColor: AppColors.surface, surfaceTintColor: Colors.transparent),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, contentTextStyle: text(15, FontWeight.w500, AppColors.background)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.line),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primarySoft,
        side: BorderSide(color: AppColors.line),
        labelStyle: text(14, FontWeight.w500),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: AppColors.primary),
    );
  }
}
