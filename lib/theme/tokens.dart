// Design tokens from the Open Maternity design system (tokens.json).
// Colours are checked for WCAG AA contrast in all three themes.
import 'package:flutter/material.dart';

enum OmThemeId { light, dark, night }

@immutable
class OmColors extends ThemeExtension<OmColors> {
  const OmColors({
    required this.id,
    required this.brightness,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.inkMuted,
    required this.clay,
    required this.onClay,
    required this.claySoft,
    required this.onClaySoft,
    required this.sage,
    required this.onSage,
    required this.sageSoft,
    required this.onSageSoft,
    required this.honey,
    required this.onHoney,
    required this.honeySoft,
    required this.onHoneySoft,
    required this.urgent,
    required this.onUrgent,
    required this.urgentSoft,
    required this.onUrgentSoft,
    required this.sky,
    required this.focus,
    required this.scrim,
    required this.raisedShadow,
  });

  final OmThemeId id;
  final Brightness brightness;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSunken;
  final Color line;
  final Color lineStrong;
  final Color ink;
  final Color inkMuted;
  final Color clay;
  final Color onClay;
  final Color claySoft;
  final Color onClaySoft;
  final Color sage;
  final Color onSage;
  final Color sageSoft;
  final Color onSageSoft;
  final Color honey;
  final Color onHoney;
  final Color honeySoft;
  final Color onHoneySoft;
  final Color urgent;
  final Color onUrgent;
  final Color urgentSoft;
  final Color onUrgentSoft;
  final Color sky;
  final Color focus;
  final Color scrim;
  final List<BoxShadow> raisedShadow;

  Color get chart1 => clay;
  Color get chart2 => sage;
  Color get chart3 => honey;
  Color get chart4 => sky;

  static const OmColors light = OmColors(
    id: OmThemeId.light,
    brightness: Brightness.light,
    surface: Color(0xFFFBF6F0),
    surfaceRaised: Color(0xFFFFFDFA),
    surfaceSunken: Color(0xFFF3EAE0),
    line: Color(0xFFE8DCCD),
    lineStrong: Color(0xFF94806F),
    ink: Color(0xFF2E241F),
    inkMuted: Color(0xFF685850),
    clay: Color(0xFFA8502F),
    onClay: Color(0xFFFFFFFF),
    claySoft: Color(0xFFF7E0D4),
    onClaySoft: Color(0xFF7A3519),
    sage: Color(0xFF4D7065),
    onSage: Color(0xFFFFFFFF),
    sageSoft: Color(0xFFDCE9E3),
    onSageSoft: Color(0xFF2F4D43),
    honey: Color(0xFFB97D22),
    onHoney: Color(0xFF1A120E),
    honeySoft: Color(0xFFFBEBCF),
    onHoneySoft: Color(0xFF6E4708),
    urgent: Color(0xFFB3123B),
    onUrgent: Color(0xFFFFFFFF),
    urgentSoft: Color(0xFFFCE1E5),
    onUrgentSoft: Color(0xFF8A0C2C),
    sky: Color(0xFF3F7196),
    focus: Color(0xFF1E5F7A),
    scrim: Color(0x7A1C1410),
    raisedShadow: <BoxShadow>[
      BoxShadow(color: Color(0x0F2E241F), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x122E241F), blurRadius: 16, offset: Offset(0, 4)),
    ],
  );

  static const OmColors dark = OmColors(
    id: OmThemeId.dark,
    brightness: Brightness.dark,
    surface: Color(0xFF1C1714),
    surfaceRaised: Color(0xFF272019),
    surfaceSunken: Color(0xFF15110E),
    line: Color(0xFF3A3029),
    lineStrong: Color(0xFF8A7868),
    ink: Color(0xFFF2E9E0),
    inkMuted: Color(0xFFC2B1A2),
    clay: Color(0xFFE89A78),
    onClay: Color(0xFF2A130A),
    claySoft: Color(0xFF4A2A1E),
    onClaySoft: Color(0xFFFAD7C6),
    sage: Color(0xFF93BBAE),
    onSage: Color(0xFF10241E),
    sageSoft: Color(0xFF233630),
    onSageSoft: Color(0xFFCDE5DB),
    honey: Color(0xFFE0B062),
    onHoney: Color(0xFF2A1D08),
    honeySoft: Color(0xFF4A3816),
    onHoneySoft: Color(0xFFF5D9A6),
    urgent: Color(0xFFF58C9C),
    onUrgent: Color(0xFF3B0510),
    urgentSoft: Color(0xFF4F1420),
    onUrgentSoft: Color(0xFFFFD0D7),
    sky: Color(0xFF8FB8D6),
    focus: Color(0xFF8CC4DC),
    scrim: Color(0x8F000000),
    raisedShadow: <BoxShadow>[],
  );

  /// Dim, warm colours for timing contractions at night.
  static const OmColors night = OmColors(
    id: OmThemeId.night,
    brightness: Brightness.dark,
    surface: Color(0xFF110C0A),
    surfaceRaised: Color(0xFF1A1310),
    surfaceSunken: Color(0xFF0B0806),
    line: Color(0xFF2A1F19),
    lineStrong: Color(0xFF7D6756),
    ink: Color(0xFFD9BFA3),
    inkMuted: Color(0xFFA68A72),
    clay: Color(0xFFC98462),
    onClay: Color(0xFF140B07),
    claySoft: Color(0xFF33201A),
    onClaySoft: Color(0xFFE0B394),
    sage: Color(0xFF7FA195),
    onSage: Color(0xFF0B1612),
    sageSoft: Color(0xFF18241F),
    onSageSoft: Color(0xFFA9C7BB),
    honey: Color(0xFFC49A55),
    onHoney: Color(0xFF160F05),
    honeySoft: Color(0xFF2E2410),
    onHoneySoft: Color(0xFFD9B57C),
    urgent: Color(0xFFE07A88),
    onUrgent: Color(0xFF1A0306),
    urgentSoft: Color(0xFF36101A),
    onUrgentSoft: Color(0xFFF0B0BA),
    sky: Color(0xFF7D9FB8),
    focus: Color(0xFF7AA8BC),
    scrim: Color(0xA3000000),
    raisedShadow: <BoxShadow>[],
  );

  static OmColors of(OmThemeId id) {
    switch (id) {
      case OmThemeId.light:
        return light;
      case OmThemeId.dark:
        return dark;
      case OmThemeId.night:
        return night;
    }
  }

  @override
  OmColors copyWith() => this;

  @override
  OmColors lerp(covariant ThemeExtension<OmColors>? other, double t) {
    if (other is! OmColors) {
      return this;
    }
    return t < 0.5 ? this : other;
  }
}

/// Type scale. Text uses Atkinson Hyperlegible Next; display sizes use Fraunces.
/// 14 px is the smallest size used anywhere.
abstract final class OmText {
  static const String textFamily = 'Atkinson Hyperlegible Next';
  static const String displayFamily = 'Fraunces';

  static const TextStyle display = TextStyle(fontFamily: displayFamily, fontSize: 34, height: 40 / 34, fontWeight: FontWeight.w600);
  static const TextStyle headline = TextStyle(fontFamily: displayFamily, fontSize: 26, height: 32 / 26, fontWeight: FontWeight.w600);
  static const TextStyle titleLg = TextStyle(fontFamily: textFamily, fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w700);
  static const TextStyle title = TextStyle(fontFamily: textFamily, fontSize: 17, height: 24 / 17, fontWeight: FontWeight.w700);
  static const TextStyle bodyLg = TextStyle(fontFamily: textFamily, fontSize: 18, height: 28 / 18, fontWeight: FontWeight.w400);
  static const TextStyle body = TextStyle(fontFamily: textFamily, fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400);
  static const TextStyle label = TextStyle(fontFamily: textFamily, fontSize: 16, height: 20 / 16, fontWeight: FontWeight.w700);
  static const TextStyle caption = TextStyle(fontFamily: textFamily, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400);
  static const TextStyle captionBold = TextStyle(fontFamily: textFamily, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w700);
  static const TextStyle numeralXl = TextStyle(
    fontFamily: textFamily,
    fontSize: 56,
    height: 60 / 56,
    fontWeight: FontWeight.w600,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );
  static const TextStyle numeralLg = TextStyle(
    fontFamily: textFamily,
    fontSize: 32,
    height: 36 / 32,
    fontWeight: FontWeight.w600,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );
  static const TextStyle time = TextStyle(
    fontFamily: textFamily,
    fontSize: 16,
    height: 20 / 16,
    fontWeight: FontWeight.w700,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );
}

/// Spacing, radii and sizes.
abstract final class OmSize {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 24;
  static const double s6 = 32;
  static const double s7 = 48;
  static const double s8 = 64;

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 20;
  static const double radiusXl = 28;

  static const double touchMin = 48;
  static const double buttonHeight = 56;
  static const double timerButton = 176;
}

extension OmContext on BuildContext {
  OmColors get om => Theme.of(this).extension<OmColors>() ?? OmColors.light;
}
