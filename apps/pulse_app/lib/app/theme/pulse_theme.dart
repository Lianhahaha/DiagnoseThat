import 'package:flutter/material.dart';

/// Named accent presets for appearance settings.
enum PulseAccentPreset { lime, blue, green, purple, orange, custom }

/// Ambient holder so legacy `PulseTokens.*` call sites track the active theme
/// without requiring a [BuildContext]. Synced from [PulseApp]'s builder and
/// [AppShell] on every Material theme animation frame.
class PulseThemeScope {
  static PulseThemeData current = PulseThemeData.dark();

  /// Bumped whenever [apply] installs a new palette. UI that cannot depend on
  /// [Theme.of] may listen to this to force a rebuild.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void apply(PulseThemeData theme) {
    current = theme;
    revision.value = revision.value + 1;
  }

  /// Apply without bumping [revision] (used on every animation tick where the
  /// shell already rebuilds via [Theme.of]).
  static void sync(PulseThemeData theme) {
    current = theme;
  }
}

/// Convenient access to Pulse design tokens from a [BuildContext].
extension PulseThemeX on BuildContext {
  PulseThemeData get pulseTheme =>
      Theme.of(this).extension<PulseThemeData>() ?? PulseThemeScope.current;
}

/// Typed Pulse design tokens carried as a [ThemeExtension].
///
/// Pulse Dark and Pulse Light are first-class palettes — Light is never a
/// simple inversion of Dark. Prefer semantic getters ([background], [card],
/// [primaryText], …) for new code; legacy field names remain supported.
class PulseThemeData extends ThemeExtension<PulseThemeData> {
  const PulseThemeData({
    required this.brightness,
    required this.canvas,
    required this.canvasTint,
    required this.sidebar,
    required this.sidebarSolid,
    required this.header,
    required this.micaOverlay,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceHover,
    required this.surfacePressed,
    required this.acrylicFill,
    required this.stroke,
    required this.strokeSubtle,
    required this.strokeStrong,
    required this.focusRing,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.accent,
    required this.accentMuted,
    required this.accentSoft,
    required this.onAccent,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.error,
    required this.errorSoft,
    required this.info,
    required this.infoSoft,
    required this.severityInfo,
    required this.severityWarning,
    required this.severityError,
    required this.severitySuccess,
    required this.severityCritical,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusXl,
    required this.radiusCard,
    required this.radiusPill,
    required this.radiusIconWell,
    required this.radiusProcessIcon,
    required this.spaceXs,
    required this.spaceSm,
    required this.spaceMd,
    required this.spaceLg,
    required this.spaceXl,
    required this.space2xl,
    required this.motionFast,
    required this.motionNormal,
    required this.motionSlow,
    required this.motionPage,
    required this.motionCurve,
    required this.motionEmphasized,
  });

  final Brightness brightness;

  // Surfaces
  final Color canvas;
  final Color canvasTint;
  final Color sidebar;
  final Color sidebarSolid;
  final Color header;
  final Color micaOverlay;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceHover;
  final Color surfacePressed;
  final Color acrylicFill;

  // Semantic aliases (independent values live in the factories above).
  Color get background => canvas;
  Color get surfaceVariant => surfaceElevated;
  Color get card => surface;
  Color get border => stroke;
  Color get divider => strokeSubtle;
  Color get primaryText => textPrimary;
  Color get secondaryText => textSecondary;
  Color get hover => surfaceHover;
  Color get pressed => surfacePressed;
  Color get selected => accentSoft;

  // Strokes / focus
  final Color stroke;
  final Color strokeSubtle;
  final Color strokeStrong;
  final Color focusRing;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;

  // Accent
  final Color accent;
  final Color accentMuted;
  final Color accentSoft;
  final Color onAccent;

  // Semantic
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color error;
  final Color errorSoft;
  final Color info;
  final Color infoSoft;

  // Severity
  final Color severityInfo;
  final Color severityWarning;
  final Color severityError;
  final Color severitySuccess;
  final Color severityCritical;

  // Radii
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusXl;
  final double radiusCard;
  final double radiusPill;
  final double radiusIconWell;
  final double radiusProcessIcon;

  // Spacing
  final double spaceXs;
  final double spaceSm;
  final double spaceMd;
  final double spaceLg;
  final double spaceXl;
  final double space2xl;

  // Motion
  final Duration motionFast;
  final Duration motionNormal;
  final Duration motionSlow;
  final Duration motionPage;
  final Curve motionCurve;
  final Curve motionEmphasized;

  /// Midnight signature lime (ADR-012).
  static const Color accentLime = Color(0xFFC8F04A);
  static const Color defaultAccent = accentLime;

  static const Color accentBlue = Color(0xFF60CDFF);
  static const Color accentGreen = Color(0xFF34D399);
  static const Color accentPurple = Color(0xFFA78BFA);
  static const Color accentOrange = Color(0xFFFB923C);

  /// Accent swatch for Settings chips — deeper on light surfaces for contrast.
  static Color accentForPreset(String preset, Brightness brightness) {
    final Color base;
    switch (preset) {
      case 'lime':
        base = accentLime;
      case 'green':
        base = accentGreen;
      case 'purple':
        base = accentPurple;
      case 'orange':
        base = accentOrange;
      case 'blue':
      default:
        base = accentBlue;
    }
    return brightness == Brightness.light ? _lightAccent(base) : base;
  }

  /// Layout constants (theme-independent).
  static const double iconSm = 14;
  static const double iconMd = 16;
  static const double iconLg = 18;
  static const double iconNav = 20;
  static const double sidebarWidth = 256;
  static const double sidebarNarrow = 216;
  static const double railWidth = 76;
  static const double shellGutter = 12;
  static const double appBarHeight = 52;
  static const double contentMaxWidth = 1600;
  static const double windowMinWidth = 1200;
  static const double windowMinHeight = 800;
  static const double windowDefaultWidth = 1440;
  static const double windowDefaultHeight = 900;
  static const double pagePadX = 32;
  static const double pagePadTop = 20;
  static const double pagePadBottom = 40;

  /// Pulse Midnight (ADR-012) — near-black canvas, flat panels, hairline
  /// borders. Information severity is blue so the accent never reads as a
  /// severity level.
  factory PulseThemeData.dark({Color accent = defaultAccent}) {
    final derived = _deriveAccent(accent, Brightness.dark);
    return PulseThemeData(
      brightness: Brightness.dark,
      canvas: const Color(0xFF08080A),
      canvasTint: const Color(0xFF0D0D10),
      sidebar: const Color(0xFF111114),
      sidebarSolid: const Color(0xFF111114),
      header: const Color(0xFF08080A),
      micaOverlay: const Color(0x00000000),
      surface: const Color(0xFF111114),
      surfaceElevated: const Color(0xFF17171B),
      surfaceHover: const Color(0xFF1E1E23),
      surfacePressed: const Color(0xFF26262C),
      acrylicFill: const Color(0xF2111114),
      stroke: const Color(0x14FFFFFF),
      strokeSubtle: const Color(0x0FFFFFFF),
      strokeStrong: const Color(0x24FFFFFF),
      focusRing: derived.focusRing,
      textPrimary: const Color(0xFFF4F4F5),
      textSecondary: const Color(0xFFA1A1AA),
      textTertiary: const Color(0xFF8B8B94),
      textDisabled: const Color(0xFF52525B),
      accent: accent,
      accentMuted: derived.muted,
      accentSoft: derived.soft,
      onAccent: derived.onAccent,
      success: const Color(0xFF34D399),
      successSoft: const Color(0xFF0F2A21),
      warning: const Color(0xFFFFB224),
      warningSoft: const Color(0xFF2D2310),
      error: const Color(0xFFFF6B6B),
      errorSoft: const Color(0xFF2D1415),
      info: const Color(0xFF6BA4FF),
      infoSoft: const Color(0xFF14213A),
      severityInfo: const Color(0xFF6BA4FF),
      severityWarning: const Color(0xFFFFB224),
      severityError: const Color(0xFFFF6B6B),
      severitySuccess: const Color(0xFF34D399),
      severityCritical: const Color(0xFFFF4D5E),
      radiusSm: 8,
      radiusMd: 10,
      radiusLg: 12,
      radiusXl: 18,
      radiusCard: 18,
      radiusPill: 999,
      radiusIconWell: 12,
      radiusProcessIcon: 8,
      spaceXs: 4,
      spaceSm: 8,
      spaceMd: 16,
      spaceLg: 24,
      spaceXl: 32,
      space2xl: 48,
      motionFast: const Duration(milliseconds: 110),
      motionNormal: const Duration(milliseconds: 170),
      motionSlow: const Duration(milliseconds: 280),
      motionPage: const Duration(milliseconds: 240),
      motionCurve: Curves.easeOutCubic,
      motionEmphasized: Curves.easeOutQuint,
    );
  }

  /// Pulse Midnight light — neutral zinc surfaces with a darkened accent so
  /// accent text and fills keep contrast on pale backgrounds.
  factory PulseThemeData.light({Color accent = defaultAccent}) {
    final lightAccent = _lightAccent(accent);
    final derived = _deriveAccent(lightAccent, Brightness.light);
    return PulseThemeData(
      brightness: Brightness.light,
      canvas: const Color(0xFFEDEDF0),
      canvasTint: const Color(0xFFE6E6EA),
      sidebar: const Color(0xFFFFFFFF),
      sidebarSolid: const Color(0xFFFFFFFF),
      header: const Color(0xFFEDEDF0),
      micaOverlay: const Color(0x00000000),
      surface: const Color(0xFFFFFFFF),
      surfaceElevated: const Color(0xFFF7F7F8),
      surfaceHover: const Color(0xFFF0F0F2),
      surfacePressed: const Color(0xFFE4E4E7),
      acrylicFill: const Color(0xF2FFFFFF),
      stroke: const Color(0xFFE4E4E7),
      strokeSubtle: const Color(0xFFEDEDF0),
      strokeStrong: const Color(0xFFD4D4D8),
      focusRing: derived.focusRing,
      textPrimary: const Color(0xFF09090B),
      textSecondary: const Color(0xFF52525B),
      textTertiary: const Color(0xFF71717A),
      textDisabled: const Color(0xFFA1A1AA),
      accent: lightAccent,
      accentMuted: derived.muted,
      accentSoft: derived.soft,
      onAccent: derived.onAccent,
      success: const Color(0xFF047857),
      successSoft: const Color(0xFFDDF5EA),
      warning: const Color(0xFF9A5B00),
      warningSoft: const Color(0xFFFFF3D6),
      error: const Color(0xFFC81E1E),
      errorSoft: const Color(0xFFFDE7E7),
      info: const Color(0xFF1D4ED8),
      infoSoft: const Color(0xFFE3EBFD),
      severityInfo: const Color(0xFF1D4ED8),
      severityWarning: const Color(0xFF9A5B00),
      severityError: const Color(0xFFC81E1E),
      severitySuccess: const Color(0xFF047857),
      severityCritical: const Color(0xFFA4161A),
      radiusSm: 8,
      radiusMd: 10,
      radiusLg: 12,
      radiusXl: 18,
      radiusCard: 18,
      radiusPill: 999,
      radiusIconWell: 12,
      radiusProcessIcon: 8,
      spaceXs: 4,
      spaceSm: 8,
      spaceMd: 16,
      spaceLg: 24,
      spaceXl: 32,
      space2xl: 48,
      motionFast: const Duration(milliseconds: 110),
      motionNormal: const Duration(milliseconds: 170),
      motionSlow: const Duration(milliseconds: 280),
      motionPage: const Duration(milliseconds: 240),
      motionCurve: Curves.easeOutCubic,
      motionEmphasized: Curves.easeOutQuint,
    );
  }

  /// Midnight is flat in dark mode: surfaces separate by tone and hairline
  /// borders. Light mode keeps a barely visible lift.
  List<BoxShadow> elevationSoft() {
    if (brightness == Brightness.light) {
      return [
        BoxShadow(
          color: const Color(0xFF09090B).withValues(alpha: 0.04),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];
    }
    return const [];
  }

  List<BoxShadow> elevation1() {
    if (brightness == Brightness.light) {
      return [
        BoxShadow(
          color: const Color(0xFF1C1E24).withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: const Color(0xFF1C1E24).withValues(alpha: 0.03),
          blurRadius: 1,
          offset: const Offset(0, 1),
        ),
      ];
    }
    return [
      BoxShadow(
        color: const Color(0xFF050508).withValues(alpha: 0.4),
        blurRadius: 12,
        offset: const Offset(0, 2),
        spreadRadius: -2,
      ),
      BoxShadow(
        color: const Color(0xFF050508).withValues(alpha: 0.18),
        blurRadius: 3,
        offset: const Offset(0, 1),
      ),
    ];
  }

  List<BoxShadow> elevationLift() {
    if (brightness == Brightness.light) {
      return [
        BoxShadow(
          color: const Color(0xFF1C1E24).withValues(alpha: 0.08),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: const Color(0xFF1C1E24).withValues(alpha: 0.04),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];
    }
    return [
      BoxShadow(
        color: const Color(0xFF050508).withValues(alpha: 0.45),
        blurRadius: 18,
        offset: const Offset(0, 6),
        spreadRadius: -3,
      ),
      BoxShadow(
        color: const Color(0xFF050508).withValues(alpha: 0.2),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ];
  }

  List<BoxShadow> severityGlow(Color color, {double intensity = 1}) => [
        BoxShadow(
          color: color.withValues(alpha: 0.22 * intensity),
          blurRadius: 14 * intensity,
          offset: Offset.zero,
        ),
      ];

  List<BoxShadow> newestGlow(Color color, double t) => [
        BoxShadow(
          color: color.withValues(alpha: 0.12 + (t * 0.18)),
          blurRadius: 10 + (t * 14),
          offset: const Offset(0, 2),
          spreadRadius: -2,
        ),
        ...elevationSoft(),
      ];

  @override
  PulseThemeData copyWith({
    Brightness? brightness,
    Color? canvas,
    Color? canvasTint,
    Color? sidebar,
    Color? sidebarSolid,
    Color? header,
    Color? micaOverlay,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceHover,
    Color? surfacePressed,
    Color? acrylicFill,
    Color? stroke,
    Color? strokeSubtle,
    Color? strokeStrong,
    Color? focusRing,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? accent,
    Color? accentMuted,
    Color? accentSoft,
    Color? onAccent,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? error,
    Color? errorSoft,
    Color? info,
    Color? infoSoft,
    Color? severityInfo,
    Color? severityWarning,
    Color? severityError,
    Color? severitySuccess,
    Color? severityCritical,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? radiusCard,
    double? radiusPill,
    double? radiusIconWell,
    double? radiusProcessIcon,
    double? spaceXs,
    double? spaceSm,
    double? spaceMd,
    double? spaceLg,
    double? spaceXl,
    double? space2xl,
    Duration? motionFast,
    Duration? motionNormal,
    Duration? motionSlow,
    Duration? motionPage,
    Curve? motionCurve,
    Curve? motionEmphasized,
  }) {
    return PulseThemeData(
      brightness: brightness ?? this.brightness,
      canvas: canvas ?? this.canvas,
      canvasTint: canvasTint ?? this.canvasTint,
      sidebar: sidebar ?? this.sidebar,
      sidebarSolid: sidebarSolid ?? this.sidebarSolid,
      header: header ?? this.header,
      micaOverlay: micaOverlay ?? this.micaOverlay,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceHover: surfaceHover ?? this.surfaceHover,
      surfacePressed: surfacePressed ?? this.surfacePressed,
      acrylicFill: acrylicFill ?? this.acrylicFill,
      stroke: stroke ?? this.stroke,
      strokeSubtle: strokeSubtle ?? this.strokeSubtle,
      strokeStrong: strokeStrong ?? this.strokeStrong,
      focusRing: focusRing ?? this.focusRing,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      accent: accent ?? this.accent,
      accentMuted: accentMuted ?? this.accentMuted,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      error: error ?? this.error,
      errorSoft: errorSoft ?? this.errorSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      severityInfo: severityInfo ?? this.severityInfo,
      severityWarning: severityWarning ?? this.severityWarning,
      severityError: severityError ?? this.severityError,
      severitySuccess: severitySuccess ?? this.severitySuccess,
      severityCritical: severityCritical ?? this.severityCritical,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      radiusCard: radiusCard ?? this.radiusCard,
      radiusPill: radiusPill ?? this.radiusPill,
      radiusIconWell: radiusIconWell ?? this.radiusIconWell,
      radiusProcessIcon: radiusProcessIcon ?? this.radiusProcessIcon,
      spaceXs: spaceXs ?? this.spaceXs,
      spaceSm: spaceSm ?? this.spaceSm,
      spaceMd: spaceMd ?? this.spaceMd,
      spaceLg: spaceLg ?? this.spaceLg,
      spaceXl: spaceXl ?? this.spaceXl,
      space2xl: space2xl ?? this.space2xl,
      motionFast: motionFast ?? this.motionFast,
      motionNormal: motionNormal ?? this.motionNormal,
      motionSlow: motionSlow ?? this.motionSlow,
      motionPage: motionPage ?? this.motionPage,
      motionCurve: motionCurve ?? this.motionCurve,
      motionEmphasized: motionEmphasized ?? this.motionEmphasized,
    );
  }

  @override
  PulseThemeData lerp(ThemeExtension<PulseThemeData>? other, double t) {
    if (other is! PulseThemeData) return this;
    return PulseThemeData(
      brightness: t < 0.5 ? brightness : other.brightness,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      canvasTint: Color.lerp(canvasTint, other.canvasTint, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      sidebarSolid: Color.lerp(sidebarSolid, other.sidebarSolid, t)!,
      header: Color.lerp(header, other.header, t)!,
      micaOverlay: Color.lerp(micaOverlay, other.micaOverlay, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated:
          Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceHover: Color.lerp(surfaceHover, other.surfaceHover, t)!,
      surfacePressed: Color.lerp(surfacePressed, other.surfacePressed, t)!,
      acrylicFill: Color.lerp(acrylicFill, other.acrylicFill, t)!,
      stroke: Color.lerp(stroke, other.stroke, t)!,
      strokeSubtle: Color.lerp(strokeSubtle, other.strokeSubtle, t)!,
      strokeStrong: Color.lerp(strokeStrong, other.strokeStrong, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentMuted: Color.lerp(accentMuted, other.accentMuted, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorSoft: Color.lerp(errorSoft, other.errorSoft, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSoft: Color.lerp(infoSoft, other.infoSoft, t)!,
      severityInfo: Color.lerp(severityInfo, other.severityInfo, t)!,
      severityWarning: Color.lerp(severityWarning, other.severityWarning, t)!,
      severityError: Color.lerp(severityError, other.severityError, t)!,
      severitySuccess: Color.lerp(severitySuccess, other.severitySuccess, t)!,
      severityCritical:
          Color.lerp(severityCritical, other.severityCritical, t)!,
      radiusSm: _lerpDouble(radiusSm, other.radiusSm, t),
      radiusMd: _lerpDouble(radiusMd, other.radiusMd, t),
      radiusLg: _lerpDouble(radiusLg, other.radiusLg, t),
      radiusXl: _lerpDouble(radiusXl, other.radiusXl, t),
      radiusCard: _lerpDouble(radiusCard, other.radiusCard, t),
      radiusPill: _lerpDouble(radiusPill, other.radiusPill, t),
      radiusIconWell: _lerpDouble(radiusIconWell, other.radiusIconWell, t),
      radiusProcessIcon:
          _lerpDouble(radiusProcessIcon, other.radiusProcessIcon, t),
      spaceXs: _lerpDouble(spaceXs, other.spaceXs, t),
      spaceSm: _lerpDouble(spaceSm, other.spaceSm, t),
      spaceMd: _lerpDouble(spaceMd, other.spaceMd, t),
      spaceLg: _lerpDouble(spaceLg, other.spaceLg, t),
      spaceXl: _lerpDouble(spaceXl, other.spaceXl, t),
      space2xl: _lerpDouble(space2xl, other.space2xl, t),
      motionFast: t < 0.5 ? motionFast : other.motionFast,
      motionNormal: t < 0.5 ? motionNormal : other.motionNormal,
      motionSlow: t < 0.5 ? motionSlow : other.motionSlow,
      motionPage: t < 0.5 ? motionPage : other.motionPage,
      motionCurve: t < 0.5 ? motionCurve : other.motionCurve,
      motionEmphasized: t < 0.5 ? motionEmphasized : other.motionEmphasized,
    );
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;

  static const Color _darkPanel = Color(0xFF111114);
  static const double _darkAccentWashAlpha = 0.14;

  /// Map a dark-leaning accent to a light-surface accent without inventing hues.
  static Color _lightAccent(Color accent) {
    if (accent == accentLime) {
      return const Color(0xFF4D7C0F); // lime-700: readable on white
    }
    if (accent == accentBlue) {
      return const Color(0xFF0F6CBD); // Win11 Settings blue
    }
    final hsv = HSVColor.fromColor(accent);
    return hsv
        .withSaturation((hsv.saturation * 0.92).clamp(0.35, 1.0))
        .withValue((hsv.value * 0.78).clamp(0.35, 0.78))
        .toColor();
  }

  static ({Color muted, Color soft, Color onAccent, Color focusRing})
      _deriveAccent(Color accent, Brightness brightness) {
    final hsv = HSVColor.fromColor(accent);

    final muted = hsv
        .withSaturation((hsv.saturation * 0.55).clamp(0.0, 1.0))
        .withValue(
          brightness == Brightness.dark
              ? (hsv.value * 0.65).clamp(0.2, 1.0)
              : (hsv.value * 0.72).clamp(0.35, 0.9),
        )
        .toColor();

    // Dark: a 14 % accent wash over the Midnight panel color, so selected
    // states read as the accent rather than a muddy desaturated tone.
    final soft = brightness == Brightness.dark
        ? Color.alphaBlend(
            accent.withValues(alpha: _darkAccentWashAlpha),
            _darkPanel,
          )
        : hsv
            .withSaturation((hsv.saturation * 0.18).clamp(0.0, 1.0))
            .withValue(0.93)
            .toColor();

    final onAccent = accent.computeLuminance() > 0.45
        ? const Color(0xFF09090B)
        : const Color(0xFFF5F7FA);

    final focusRing = hsv
        .withSaturation((hsv.saturation * 0.95).clamp(0.0, 1.0))
        .withValue((hsv.value * 1.05).clamp(0.0, 1.0))
        .toColor();

    return (
      muted: muted,
      soft: soft,
      onAccent: onAccent,
      focusRing: focusRing,
    );
  }
}

/// Ambient token accessors used across the app.
///
/// Colors and motion durations read from [PulseThemeScope.current].
/// Radii, spacing, and layout sizes remain static const.
abstract final class PulseTokens {
  static PulseThemeData get _t => PulseThemeScope.current;

  // Surfaces
  static Brightness get brightness => _t.brightness;

  static Color get canvas => _t.canvas;
  static Color get background => _t.background;
  static Color get canvasTint => _t.canvasTint;
  static Color get sidebar => _t.sidebar;
  static Color get sidebarSolid => _t.sidebarSolid;
  static Color get header => _t.header;
  static Color get micaOverlay => _t.micaOverlay;
  static Color get surface => _t.surface;
  static Color get surfaceVariant => _t.surfaceVariant;
  static Color get card => _t.card;
  static Color get surfaceElevated => _t.surfaceElevated;
  static Color get surfaceHover => _t.surfaceHover;
  static Color get hover => _t.hover;
  static Color get surfacePressed => _t.surfacePressed;
  static Color get pressed => _t.pressed;
  static Color get selected => _t.selected;
  static Color get acrylicFill => _t.acrylicFill;
  static Color get border => _t.border;
  static Color get divider => _t.divider;
  static Color get primaryText => _t.primaryText;
  static Color get secondaryText => _t.secondaryText;

  static Color get stroke => _t.stroke;
  static Color get strokeSubtle => _t.strokeSubtle;
  static Color get strokeStrong => _t.strokeStrong;
  static Color get focusRing => _t.focusRing;

  static Color get textPrimary => _t.textPrimary;
  static Color get textSecondary => _t.textSecondary;
  static Color get textTertiary => _t.textTertiary;
  static Color get textDisabled => _t.textDisabled;

  static Color get accent => _t.accent;
  static Color get accentMuted => _t.accentMuted;
  static Color get accentSoft => _t.accentSoft;
  static Color get onAccent => _t.onAccent;

  static Color get success => _t.success;
  static Color get successSoft => _t.successSoft;
  static Color get warning => _t.warning;
  static Color get warningSoft => _t.warningSoft;
  static Color get error => _t.error;
  static Color get errorSoft => _t.errorSoft;
  static Color get info => _t.info;
  static Color get infoSoft => _t.infoSoft;

  static Color get severityInfo => _t.severityInfo;
  static Color get severityWarning => _t.severityWarning;
  static Color get severityError => _t.severityError;
  static Color get severitySuccess => _t.severitySuccess;
  static Color get severityCritical => _t.severityCritical;

  static const double radiusSm = 8;
  static const double radiusMd = 10;
  static const double radiusLg = 12;
  static const double radiusXl = 18;
  static const double radiusCard = 18;
  static const double radiusPill = 999;
  static const double radiusIconWell = 12;
  static const double radiusProcessIcon = 8;

  static const double iconSm = 14;
  static const double iconMd = 16;
  static const double iconLg = 18;
  static const double iconNav = PulseThemeData.iconNav;

  static const double sidebarWidth = 256;
  static const double sidebarNarrow = 216;
  static const double railWidth = PulseThemeData.railWidth;
  static const double shellGutter = PulseThemeData.shellGutter;
  static const double appBarHeight = 52;
  static const double contentMaxWidth = 1600;

  static const double windowMinWidth = 1200;
  static const double windowMinHeight = 800;
  static const double windowDefaultWidth = 1440;
  static const double windowDefaultHeight = 900;

  static const double pagePadX = 32;
  static const double pagePadTop = 20;
  static const double pagePadBottom = 40;

  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;
  static const double space2xl = 48;

  static Duration get motionFast => _t.motionFast;
  static Duration get motionNormal => _t.motionNormal;
  static Duration get motionSlow => _t.motionSlow;
  static Duration get motionPage => _t.motionPage;
  static const Curve motionCurve = Curves.easeOutCubic;
  static const Curve motionEmphasized = Curves.easeOutQuint;

  /// Scales a motion duration by [speed] (typically [SettingsController.animationSpeed]).
  static Duration scaleMotion(Duration base, double speed) {
    if (speed == 1.0) return base;
    if (speed <= 0) return Duration.zero;
    return Duration(
      microseconds: (base.inMicroseconds * speed).round().clamp(0, 1 << 62),
    );
  }

  static List<BoxShadow> get elevationSoft => _t.elevationSoft();
  static List<BoxShadow> get elevation1 => _t.elevation1();
  static List<BoxShadow> get elevationLift => _t.elevationLift();

  static List<BoxShadow> severityGlow(Color color, {double intensity = 1}) =>
      _t.severityGlow(color, intensity: intensity);

  static List<BoxShadow> newestGlow(Color color, double t) =>
      _t.newestGlow(color, t);
}

class PulseTheme {
  /// Bundled UI family (assets/fonts, OFL). See ADR-012.
  static const String _font = 'Geist';

  /// Bundled monospace family for numbers, identifiers and raw XML.
  static const String monoFont = 'GeistMono';

  /// Fallbacks when a glyph is missing from Geist (e.g. rare scripts).
  static const List<String> fontFallback = ['Segoe UI Variable Text', 'Segoe UI'];
  static const List<String> monoFallback = ['Cascadia Mono', 'Consolas'];

  static ThemeData dark({Color? accent}) {
    final tokens = PulseThemeData.dark(accent: accent ?? PulseThemeData.defaultAccent);
    return _build(tokens, Brightness.dark);
  }

  static ThemeData light({Color? accent}) {
    final tokens = PulseThemeData.light(accent: accent ?? PulseThemeData.defaultAccent);
    return _build(tokens, Brightness.light);
  }

  static ThemeData _build(PulseThemeData tokens, Brightness brightness) {
    final base = (brightness == Brightness.dark
            ? ThemeData.dark(useMaterial3: true)
            : ThemeData.light(useMaterial3: true))
        .textTheme
        .apply(
          fontFamily: _font,
          fontFamilyFallback: fontFallback,
          bodyColor: tokens.textPrimary,
          displayColor: tokens.textPrimary,
        );

    final textTheme = base.copyWith(
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.9,
        fontSize: 30,
        height: 1.2,
        color: tokens.textPrimary,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.55,
        fontSize: 22,
        height: 1.28,
        color: tokens.textPrimary,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        fontSize: 20,
        height: 1.28,
        color: tokens.textPrimary,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.15,
        fontSize: 15,
        height: 1.38,
        color: tokens.textPrimary,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 13,
        height: 1.35,
        color: tokens.textSecondary,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        height: 1.55,
        fontSize: 15,
        color: tokens.textPrimary,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        height: 1.5,
        fontSize: 14,
        color: tokens.textSecondary,
      ),
      bodySmall: base.bodySmall?.copyWith(
        height: 1.5,
        fontSize: 12,
        letterSpacing: 0.02,
        color: tokens.textTertiary,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        height: 1.2,
        color: tokens.textPrimary,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 12,
        height: 1.2,
        color: tokens.textSecondary,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 10.5,
        letterSpacing: 0.35,
        height: 1.2,
        color: tokens.textTertiary,
      ),
    );

    final colorScheme = brightness == Brightness.dark
        ? ColorScheme.dark(
            surface: tokens.surface,
            primary: tokens.accent,
            onPrimary: tokens.onAccent,
            secondary: tokens.textSecondary,
            onSurface: tokens.textPrimary,
            outline: tokens.stroke,
            error: tokens.error,
          )
        : ColorScheme.light(
            surface: tokens.surface,
            primary: tokens.accent,
            onPrimary: tokens.onAccent,
            secondary: tokens.textSecondary,
            onSurface: tokens.textPrimary,
            outline: tokens.stroke,
            error: tokens.error,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: _font,
      fontFamilyFallback: fontFallback,
      scaffoldBackgroundColor: tokens.canvas,
      canvasColor: tokens.canvas,
      cardColor: tokens.surface,
      colorScheme: colorScheme,
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return tokens.textDisabled;
          }
          // Keep thumb clearly visible on hover/pressed against track.
          if (states.contains(WidgetState.selected)) {
            return tokens.onAccent;
          }
          return brightness == Brightness.dark
              ? const Color(0xFFE8ECF0)
              : const Color(0xFFFFFFFF);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return tokens.strokeSubtle;
          }
          if (states.contains(WidgetState.selected)) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed)) {
              return tokens.accentMuted;
            }
            return tokens.accent;
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.pressed)) {
            return tokens.stroke;
          }
          return tokens.strokeSubtle;
        }),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return tokens.accent.withValues(alpha: 0.08);
          }
          if (states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.focused)) {
            return tokens.accent.withValues(alpha: 0.12);
          }
          return Colors.transparent;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return tokens.stroke.withValues(alpha: 0.9);
        }),
      ),
      textTheme: textTheme,
      dividerColor: tokens.strokeSubtle,
      dividerTheme: DividerThemeData(
        color: tokens.strokeSubtle,
        thickness: 1,
        space: 1,
      ),
      splashFactory: InkSparkle.splashFactory,
      focusColor: tokens.accent.withValues(alpha: 0.14),
      hoverColor: tokens.surfaceHover.withValues(alpha: 0.55),
      highlightColor: tokens.accent.withValues(alpha: 0.06),
      extensions: [tokens],
      popupMenuTheme: PopupMenuThemeData(
        color: tokens.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        textStyle: textTheme.bodyMedium?.copyWith(color: tokens.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          side: BorderSide(color: tokens.stroke.withValues(alpha: 0.85)),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(tokens.surfaceElevated),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.radiusMd),
              side: BorderSide(color: tokens.stroke.withValues(alpha: 0.85)),
            ),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: tokens.surfaceElevated,
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(color: tokens.stroke),
          boxShadow: tokens.elevation1(),
        ),
        textStyle:
            textTheme.bodySmall?.copyWith(color: tokens.textPrimary),
        waitDuration: const Duration(milliseconds: 360),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      // Midnight inputs: flat panel fill, hairline border, accent on focus.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: textTheme.bodyMedium?.copyWith(color: tokens.textTertiary),
        labelStyle: textTheme.labelMedium?.copyWith(color: tokens.textSecondary),
        floatingLabelStyle:
            textTheme.labelMedium?.copyWith(color: tokens.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusLg),
          borderSide: BorderSide(color: tokens.stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusLg),
          borderSide: BorderSide(color: tokens.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusLg),
          borderSide: BorderSide(color: tokens.accent.withValues(alpha: 0.6)),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.dragged)) {
            return 9.0;
          }
          return 6.0;
        }),
        radius: const Radius.circular(999),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged)) {
            return tokens.textSecondary.withValues(alpha: 0.5);
          }
          if (states.contains(WidgetState.hovered)) {
            return tokens.textTertiary.withValues(alpha: 0.42);
          }
          return tokens.textTertiary.withValues(alpha: 0.22);
        }),
        trackColor: WidgetStateProperty.all(Colors.transparent),
        trackBorderColor: WidgetStateProperty.all(Colors.transparent),
        crossAxisMargin: 4,
        mainAxisMargin: 10,
        minThumbLength: 48,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: tokens.textSecondary,
          hoverColor: tokens.surfaceHover,
          focusColor: tokens.accent.withValues(alpha: 0.14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusMd),
          ),
          minimumSize: const Size(36, 36),
          padding: const EdgeInsets.all(8),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusXl),
          side: BorderSide(color: tokens.stroke.withValues(alpha: 0.7)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.surfaceElevated,
        contentTextStyle:
            textTheme.bodyMedium?.copyWith(color: tokens.textPrimary),
        actionTextColor: tokens.accent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          side: BorderSide(color: tokens.stroke),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
