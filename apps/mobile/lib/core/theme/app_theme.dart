import 'package:flutter/material.dart';

/// Calm clinical palette. Emergency red is reserved for critical emergency actions and warnings.
class AppColors {
  AppColors._();
  static const navy = Color(0xFF0B2545);
  static const teal = Color(0xFF0F8B8D);
  static const blue = Color(0xFF2563EB);
  static const emergency = Color(0xFFD92D20);
  static const surface = Color(0xFFFAF9F6);
  static const warning = Color(0xFFB54708);
  static const success = Color(0xFF067647);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      brightness: brightness,
      primary: isLight ? AppColors.navy : const Color(0xFF8FB8FF),
      secondary: AppColors.teal,
      error: AppColors.emergency,
      surface: isLight ? AppColors.surface : const Color(0xFF0E1621),
    );
    final cardColor = isLight ? Colors.white : const Color(0xFF16212F);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: cardColor,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: isLight ? Colors.white : const Color(0xFF111A26),
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
