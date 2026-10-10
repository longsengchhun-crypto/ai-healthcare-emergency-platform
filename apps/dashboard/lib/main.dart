import 'package:flutter/material.dart';

import 'api.dart';
import 'pages.dart';

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
  late final Api api = Api(_apiBase);
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    api.onSignedOut = () => setState(() => _signedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0B2545);
    return MaterialApp(
      title: 'HealthResponse Operations',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F8B8D),
          primary: navy,
          error: const Color(0xFFD92D20),
        ),
        scaffoldBackgroundColor: const Color(0xFFFAF9F6),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE4E7EC)),
          ),
        ),
      ),
      home: _signedIn
          ? Shell(api: api)
          : LoginPage(
              api: api,
              onSignedIn: () => setState(() => _signedIn = true),
            ),
    );
  }
}
