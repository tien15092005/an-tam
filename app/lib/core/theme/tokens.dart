import 'package:flutter/material.dart';

/// Design tokens. Screens read these through [AppTheme]; never hard-code values in widgets.
abstract final class AppColors {
  static const background = Color(0xFFFBF7F2);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1F2233);
  static const muted = Color(0xFF5E6273);
  static const line = Color(0xFFE6DED3);
  static const primary = Color(0xFFC4521C);
  static const primarySoft = Color(0xFFFDEBDF);
  static const navy = Color(0xFF283A6B);
  static const navySoft = Color(0xFFE8ECF6);
  static const ok = Color(0xFF1E7A4F);
  static const okSoft = Color(0xFFE3F4EB);
  static const warn = Color(0xFF9A5B00);
  static const warnSoft = Color(0xFFFDF1DC);
  static const danger = Color(0xFFB3261E);
  static const dangerSoft = Color(0xFFFBE6E6);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class AppRadius {
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 24.0;
}

/// Elder mode is the large, low-density variant; caregiver mode is the regular app.
enum UiDensity { caregiver, elder }

class DensityScale {
  const DensityScale._({
    required this.body,
    required this.title,
    required this.headline,
    required this.minTouchTarget,
  });

  final double body;
  final double title;
  final double headline;
  final double minTouchTarget;

  static const caregiver = DensityScale._(body: 15, title: 18, headline: 26, minTouchTarget: 48);

  // Elder rules from the plan: body >= 20sp, titles >= 32sp, primary buttons >= 72dp tall.
  static const elder = DensityScale._(body: 21, title: 32, headline: 40, minTouchTarget: 72);

  static DensityScale of(UiDensity density) => density == UiDensity.elder ? elder : caregiver;
}
