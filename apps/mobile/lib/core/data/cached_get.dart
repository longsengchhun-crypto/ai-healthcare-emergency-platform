import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../errors/app_exception.dart';

/// Read-through cache for non-sensitive directory data so lists still open when the phone is offline.
/// NEVER use for emergency status or medical records: those must always be live.
class CachedResult<T> {
  CachedResult(this.data, {this.fromCache = false, this.savedAt});
  final T data;
  final bool fromCache;
  final DateTime? savedAt;
}

Future<CachedResult<dynamic>> cachedGet(
  String key,
  Future<dynamic> Function() fetch,
) async {
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {}
  try {
    final fresh = await fetch();
    try {
      await prefs?.setString(
        'cache.$key',
        jsonEncode({'at': DateTime.now().toIso8601String(), 'data': fresh}),
      );
    } catch (_) {}
    return CachedResult(fresh);
  } on AppException catch (e) {
    final offline =
        e.kind == ErrorKind.offline ||
        e.kind == ErrorKind.timeout ||
        e.kind == ErrorKind.server;
    final raw = prefs?.getString('cache.$key');
    if (offline && raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return CachedResult(
        decoded['data'],
        fromCache: true,
        savedAt: DateTime.tryParse(decoded['at'] as String),
      );
    }
    rethrow;
  }
}
