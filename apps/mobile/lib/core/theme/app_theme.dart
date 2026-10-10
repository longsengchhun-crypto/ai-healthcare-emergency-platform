import 'package:flutter/material.dart';

import '../design/palette.dart';

/// Legacy constants kept for screens that still reference them; new code uses [Palette].
class AppColors {
  AppColors._();
  static const navy = Color(0xFF0D1B2A);
  static const teal = Color(0xFF0F7C80);
  static const blue = Color(0xFF2F5FD0);
  static const emergency = Color(0xFFD92D20);
  static const surface = Color(0xFFFAF8F4);
  static const warning = Color(0xFFA9650F);
  static const success = Color(0xFF1E7A4F);
}

class AppTheme {
  AppTheme._();

  static const _family = 'NotoSansKhmer';

  static ThemeData light() => _build(Palette.light, Brightness.light);
  static ThemeData dark() => _build(Palette.dark, Brightness.dark);

  static ThemeData _build(Palette p, Brightness b) {
    final scheme = ColorScheme(
      brightness: b,
      primary: p.ink,
      onPrimary: b == Brightness.light ? Colors.white : p.paper,
      secondary: p.teal,
      onSecondary: Colors.white,
      error: p.red,
      onError: Colors.white,
      surface: p.paper,
      onSurface: p.ink,
      outline: p.muted,
      outlineVariant: p.line,
    );

    // Khmer script needs more vertical room than Latin: generous line heights stop clipped sub-consonants.
    TextStyle s(double size, FontWeight w, {double h = 1.5, double ls = 0}) =>
        TextStyle(
          fontFamily: _family,
          fontSize: size,
          fontWeight: w,
          height: h,
          letterSpacing: ls,
          color: p.ink,
        );

    final text = TextTheme(
      displaySmall: s(30, FontWeight.w800, h: 1.3, ls: -0.4),
      headlineMedium: s(26, FontWeight.w800, h: 1.35, ls: -0.3),
      headlineSmall: s(22, FontWeight.w800, h: 1.4, ls: -0.2),
      titleLarge: s(19, FontWeight.w800, h: 1.4),
      titleMedium: s(16.5, FontWeight.w700, h: 1.45),
      titleSmall: s(14.5, FontWeight.w700, h: 1.45),
      bodyLarge: s(16, FontWeight.w500),
      bodyMedium: s(14.5, FontWeight.w500),
      bodySmall: s(12.5, FontWeight.w500),
      labelLarge: s(15, FontWeight.w700, h: 1.4),
      labelMedium: s(13, FontWeight.w700, h: 1.4),
    );

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      borderSide: BorderSide(color: c, width: w),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: _family,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.paper,
      textTheme: text,
      extensions: [p],
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: p.paper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: s(19, FontWeight.w800, h: 1.4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: TextStyle(color: p.muted),
        hintStyle: TextStyle(color: p.muted),
        border: border(p.line),
        enabledBorder: border(p.line),
        focusedBorder: border(p.teal, 1.8),
        errorBorder: border(p.red),
        focusedErrorBorder: border(p.red, 1.8),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.ink,
        side: BorderSide(color: p.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        labelStyle: TextStyle(
          color: p.ink,
          fontWeight: FontWeight.w600,
          fontFamily: _family,
        ),
        showCheckmark: false,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.selected) ? Colors.white : p.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.selected) ? p.teal : p.line,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.ink,
        unselectedLabelColor: p.muted,
        indicatorColor: p.teal,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: p.line,
        labelStyle: s(15, FontWeight.w800, h: 1.4),
        unselectedLabelStyle: s(15, FontWeight.w600, h: 1.4),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.ink,
        contentTextStyle: TextStyle(
          color: p.paper,
          fontFamily: _family,
          height: 1.4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
      ),
      listTileTheme: ListTileThemeData(iconColor: p.inkSoft, textColor: p.ink),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.teal),
    );
  }
}
