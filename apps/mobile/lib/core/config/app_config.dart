import 'package:flutter/foundation.dart';

/// Build-time configuration. Supply the API with `--dart-define=API_BASE_URL=https://...`.
class AppConfig {
  AppConfig._();

  static const String _definedBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Debug builds fall back to the Android-emulator / local host address.
  /// Release builds NEVER fall back: a missing or local URL is a configuration error.
  static String get apiBaseUrl {
    // `origin` = same host that served this web page (single-container cloud deployment).
    if (_definedBaseUrl == 'origin' && kIsWeb) return Uri.base.origin;
    if (_definedBaseUrl.isNotEmpty) return _definedBaseUrl;
    if (kReleaseMode) return '';
    return kIsWeb ? 'http://localhost:8080' : 'http://10.0.2.2:8080';
  }

  static bool get isReleaseConfigurationValid {
    if (!kReleaseMode) return true;
    final url = apiBaseUrl;
    if (url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return false;
    const local = ['localhost', '127.0.0.1', '10.0.2.2'];
    return !local.contains(uri.host);
  }

  static const String appName = 'HealthResponse';
}
