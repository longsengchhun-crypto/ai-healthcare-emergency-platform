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
    required this.brand,
    required this.brandDeep,
    required this.brandSoft,
    required this.blue,
    required this.red,
    required this.redSoft,
    required this.green,
    required this.greenSoft,
    required this.amber,
    required this.amberSoft,
  });

  final Color paper; // page background (cool off-white)
  final Color surface; // raised surfaces
  final Color sand; // quiet fills
  final Color line; // hairlines
  final Color ink; // primary text / structure
  final Color inkSoft;
  final Color muted;
  final Color brand;
  final Color brandDeep;
  final Color brandSoft;
  final Color blue;
  final Color red;
  final Color redSoft;
  final Color green;
  final Color greenSoft;
  final Color amber;
  final Color amberSoft;

  static const light = Palette(
    paper: Color(0xFFF4F7FC),
    surface: Color(0xFFFFFFFF),
    sand: Color(0xFFEBF0FA),
    line: Color(0xFFE2E8F4),
    ink: Color(0xFF111B33),
    inkSoft: Color(0xFF3F4B66),
    muted: Color(0xFF7480A0),
    brand: Color(0xFF2563EB),
    brandDeep: Color(0xFF1946B8),
    brandSoft: Color(0xFFE4ECFD),
    blue: Color(0xFF2563EB),
    red: Color(0xFFE5392B),
    redSoft: Color(0xFFFDEBE9),
    green: Color(0xFF16915F),
    greenSoft: Color(0xFFE0F5EB),
    amber: Color(0xFFB86A07),
    amberSoft: Color(0xFFFDF1DC),
  );

  static const dark = Palette(
    paper: Color(0xFF0B1220),
    surface: Color(0xFF131C2E),
    sand: Color(0xFF1A2540),
    line: Color(0xFF263250),
    ink: Color(0xFFF1F4FB),
    inkSoft: Color(0xFFC6CEE0),
    muted: Color(0xFF8A96B4),
    brand: Color(0xFF5B8CFF),
    brandDeep: Color(0xFF9DBBFF),
    brandSoft: Color(0xFF1B2C57),
    blue: Color(0xFF5B8CFF),
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
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 24;
  static const double pill = 999;
}
