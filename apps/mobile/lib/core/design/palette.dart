import 'package:flutter/material.dart';

/// Colour roles for the whole product. Emergency red appears ONLY on emergency actions and warnings.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.paper,
    required this.surface,
    required this.sand,
    required this.line,
    required this.ink,
    required this.inkSoft,
    required this.muted,
    required this.teal,
    required this.tealDeep,
    required this.tealSoft,
    required this.blue,
    required this.red,
    required this.redSoft,
    required this.green,
    required this.greenSoft,
    required this.amber,
    required this.amberSoft,
  });

  final Color paper; // page background (warm, not pure white)
  final Color surface; // raised surfaces
  final Color sand; // quiet fills
  final Color line; // hairlines
  final Color ink; // primary text / structure
  final Color inkSoft;
  final Color muted;
  final Color teal;
  final Color tealDeep;
  final Color tealSoft;
  final Color blue;
  final Color red;
  final Color redSoft;
  final Color green;
  final Color greenSoft;
  final Color amber;
  final Color amberSoft;

  static const light = Palette(
    paper: Color(0xFFFAF8F4),
    surface: Color(0xFFFFFFFF),
    sand: Color(0xFFF1EDE4),
    line: Color(0xFFE5E0D4),
    ink: Color(0xFF0D1B2A),
    inkSoft: Color(0xFF3B4A5C),
    muted: Color(0xFF6C7787),
    teal: Color(0xFF0F7C80),
    tealDeep: Color(0xFF0A5659),
    tealSoft: Color(0xFFDCEEEE),
    blue: Color(0xFF2F5FD0),
    red: Color(0xFFD92D20),
    redSoft: Color(0xFFFCE9E7),
    green: Color(0xFF1E7A4F),
    greenSoft: Color(0xFFE0F2E8),
    amber: Color(0xFFA9650F),
    amberSoft: Color(0xFFFBEFD9),
  );

  static const dark = Palette(
    paper: Color(0xFF0A1118),
    surface: Color(0xFF121C27),
    sand: Color(0xFF17232F),
    line: Color(0xFF243444),
    ink: Color(0xFFF2F5F8),
    inkSoft: Color(0xFFC5CFDA),
    muted: Color(0xFF8D9BAB),
    teal: Color(0xFF4FC3C7),
    tealDeep: Color(0xFF8AD9DB),
    tealSoft: Color(0xFF123B3F),
    blue: Color(0xFF7FA2F2),
    red: Color(0xFFFF6B5E),
    redSoft: Color(0xFF3B1814),
    green: Color(0xFF58C58E),
    greenSoft: Color(0xFF123424),
    amber: Color(0xFFE8B25B),
    amberSoft: Color(0xFF3A2A10),
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).extension<Palette>() ?? light;

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) =>
      t < 0.5 ? this : (other as Palette? ?? this);
}

/// Spacing and radius scale, so layouts snap to one rhythm instead of ad-hoc numbers.
class Gap {
  Gap._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double page = 20;
}

class Radii {
  Radii._();
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double pill = 999;
}
