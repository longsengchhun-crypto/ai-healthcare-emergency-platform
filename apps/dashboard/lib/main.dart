import 'package:flutter/material.dart';

import 'api.dart';
import 'pages.dart';

/// `origin` = the host that served this page (single-container cloud deployment).
const _apiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

void main() => runApp(const DashboardApp());

class DashboardApp extends StatefulWidget {
  const DashboardApp({super.key});

  @override
  State<DashboardApp> createState() => _DashboardAppState();
}

class _DashboardAppState extends State<DashboardApp> {
  late final Api api = Api(_apiBase == 'origin' ? Uri.base.origin : _apiBase);
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    api.onSignedOut = () => setState(() => _signedIn = false);
  }

  /// Same palette as the mobile app (ink / paper / teal; red only for emergencies).
  ThemeData _theme(Brightness b) {
    final dark = b == Brightness.dark;
    final ink = dark ? const Color(0xFFF2F5F8) : const Color(0xFF0D1B2A);
    final paper = dark ? const Color(0xFF0A1118) : const Color(0xFFFAF8F4);
    final surface = dark ? const Color(0xFF121C27) : Colors.white;
    final line = dark ? const Color(0xFF243444) : const Color(0xFFE5E0D4);
    final teal = dark ? const Color(0xFF4FC3C7) : const Color(0xFF0F7C80);
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: ColorScheme(
        brightness: b,
        primary: ink,
        onPrimary: paper,
        secondary: teal,
        onSecondary: Colors.white,
        error: const Color(0xFFD92D20),
        onError: Colors.white,
        surface: paper,
        onSurface: ink,
        outlineVariant: line,
      ),
      scaffoldBackgroundColor: paper,
      splashFactory: NoSplash.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: border(line),
        enabledBorder: border(line),
        focusedBorder: border(teal, 1.8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: paper,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: teal.withValues(alpha: 0.16),
        selectedIconTheme: IconThemeData(color: teal),
        selectedLabelTextStyle: TextStyle(
          color: ink,
          fontWeight: FontWeight.w800,
        ),
      ),
      dividerColor: line,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HealthResponse Operations',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: _signedIn
          ? Shell(api: api)
          : LoginPage(
              api: api,
              onSignedIn: () => setState(() => _signedIn = true),
            ),
    );
  }
}
