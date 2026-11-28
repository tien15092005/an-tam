import 'package:material_ui/material_ui.dart';

/// One set of colours. [AppColors] serves the light or dark one, following the phone's setting.
class Palette {
  const Palette({
    required this.background,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.primary,
    required this.primarySoft,
    required this.onAccent,
    required this.ok,
    required this.okSoft,
    required this.warn,
    required this.warnSoft,
    required this.danger,
    required this.dangerSoft,
  });

  final Color background, surface, ink, muted, line;
  final Color primary, primarySoft;

  /// Text and icons on a filled primary / ok / danger button.
  final Color onAccent;
  final Color ok, okSoft, warn, warnSoft, danger, dangerSoft;

  /// Calm blue for trust, green for "done", amber for "needs a look", red only for real problems.
  /// Text colours keep at least 4.5:1 contrast on [background] and [surface] (7:1 for [ink]).
  static const light = Palette(
    background: Color(0xFFF4F6F5),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF15211D),
    muted: Color(0xFF5A6762),
    line: Color(0xFFDCE3E0),
    primary: Color(0xFF1D5C7A),
    primarySoft: Color(0xFFE3EEF3),
    onAccent: Color(0xFFFFFFFF),
    ok: Color(0xFF1E7148),
    okSoft: Color(0xFFE2F2E8),
    warn: Color(0xFF8A5300),
    warnSoft: Color(0xFFFBF0DC),
    danger: Color(0xFFB3261E),
    dangerSoft: Color(0xFFFBE7E5),
  );

  /// Dark: accents get lighter so they stay readable; filled buttons carry dark text.
  static const dark = Palette(
    background: Color(0xFF0E1412),
    surface: Color(0xFF18211E),
    ink: Color(0xFFE6ECE9),
    muted: Color(0xFFA2AFAA),
    line: Color(0xFF2E3A36),
    primary: Color(0xFF8CC8E4),
    primarySoft: Color(0xFF1B3240),
    onAccent: Color(0xFF0B1512),
    ok: Color(0xFF7DD3A0),
    okSoft: Color(0xFF163225),
    warn: Color(0xFFF0B866),
    warnSoft: Color(0xFF3A2C12),
    danger: Color(0xFFFF8A80),
    dangerSoft: Color(0xFF3D1A18),
  );
}

/// Design tokens. The app root sets [dark] from the phone's light/dark setting and rebuilds the screens.
abstract final class AppColors {
  static bool dark = false;
  static Palette get _p => dark ? Palette.dark : Palette.light;

  static Color get background => _p.background;
  static Color get surface => _p.surface;
  static Color get ink => _p.ink;
  static Color get muted => _p.muted;
  static Color get line => _p.line;
  static Color get primary => _p.primary;
  static Color get primarySoft => _p.primarySoft;
  static Color get onAccent => _p.onAccent;

  /// "navy" was the old secondary colour; the new design uses the one blue for both.
  static Color get navy => _p.primary;
  static Color get navySoft => _p.primarySoft;
  static Color get ok => _p.ok;
  static Color get okSoft => _p.okSoft;
  static Color get warn => _p.warn;
  static Color get warnSoft => _p.warnSoft;
  static Color get danger => _p.danger;
  static Color get dangerSoft => _p.dangerSoft;
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
