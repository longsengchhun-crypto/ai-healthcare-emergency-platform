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

  /// Same palette as the mobile app (ink / paper / brand blue; red only for emergencies).
  ThemeData _theme(Brightness b) {
    final dark = b == Brightness.dark;
    final ink = dark ? const Color(0xFFF1F4FB) : const Color(0xFF111B33);
    final paper = dark ? const Color(0xFF0B1220) : const Color(0xFFF4F7FC);
    final surface = dark ? const Color(0xFF131C2E) : Colors.white;
    final line = dark ? const Color(0xFF263250) : const Color(0xFFE2E8F4);
    final brand = dark ? const Color(0xFF5B8CFF) : const Color(0xFF2563EB);
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: c, width: w),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: ColorScheme(
        brightness: b,
        primary: brand,
        onPrimary: Colors.white,
        secondary: brand,
        onSecondary: Colors.white,
        error: const Color(0xFFE5392B),
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
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: border(line),
        enabledBorder: border(line),
        focusedBorder: border(brand, 1.8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: brand.withValues(alpha: 0.14),
        selectedIconTheme: IconThemeData(color: brand),
        selectedLabelTextStyle: TextStyle(
          color: ink,
          fontWeight: FontWeight.w700,
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
