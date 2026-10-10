import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Khmer-first language switch. Strings are written inline as a pair, `context.t('ខ្មែរ', 'English')`, so the
/// translation always sits next to the widget that uses it and nothing can silently fall out of sync.
class LanguageController extends ChangeNotifier {
  String _code = 'km';
  String get code => _code;
  bool get isKhmer => _code == 'km';

  Future<void> load() async {
    await initializeDateFormatting();
    try {
      final prefs = await SharedPreferences.getInstance();
      _code = prefs.getString('ui.language') ?? 'km';
    } catch (_) {
      _code = 'km';
    }
    notifyListeners();
  }

  Future<void> set(String code) async {
    if (code == _code) return;
    _code = code;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ui.language', code);
    } catch (_) {}
  }
}

final languageController = LanguageController();

class LanguageScope extends InheritedNotifier<LanguageController> {
  const LanguageScope({
    super.key,
    required LanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static LanguageController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LanguageScope>();
    return scope?.notifier ?? languageController;
  }
}

extension TranslateX on BuildContext {
  /// Picks the Khmer or English text for the current language and rebuilds when the language changes.
  String t(String km, String en) => LanguageScope.of(this).isKhmer ? km : en;

  bool get isKhmer => LanguageScope.of(this).isKhmer;

  /// Date formatting in the active locale (falls back to English patterns if Khmer data is unavailable).
  String fmt(String pattern, DateTime date) {
    try {
      return DateFormat(pattern, LanguageScope.of(this).code).format(date);
    } catch (_) {
      return DateFormat(pattern).format(date);
    }
  }
}
