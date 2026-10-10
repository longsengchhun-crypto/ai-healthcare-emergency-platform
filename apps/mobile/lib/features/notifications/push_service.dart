import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/providers.dart';
import 'notifications_screen.dart';

/// Firebase Cloud Messaging registration.
///
/// Firebase is configured at build time with `--dart-define` values (no google-services.json is committed):
///   FIREBASE_API_KEY, FIREBASE_APP_ID, FIREBASE_MESSAGING_SENDER_ID, FIREBASE_PROJECT_ID
/// Without them push is simply disabled and the in-app inbox keeps working.
class PushService {
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  static bool get isConfigured =>
      _apiKey.isNotEmpty &&
      _appId.isNotEmpty &&
      _senderId.isNotEmpty &&
      _projectId.isNotEmpty;

  static bool _initialised = false;

  /// Returns the current device token, or null when push is unconfigured, denied or fails.
  static Future<String?> token() async {
    if (!isConfigured) return null;
    try {
      if (!_initialised) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: _apiKey,
            appId: _appId,
            messagingSenderId: _senderId,
            projectId: _projectId,
          ),
        );
        _initialised = true;
      }
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return null;
      }
      return await messaging.getToken();
    } catch (_) {
      return null;
    }
  }
}

/// Registers this device with the backend after sign-in and keeps the token fresh.
class PushRegistrar {
  PushRegistrar(this._ref);
  final Ref _ref;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  Future<void> register() async {
    final token = await PushService.token();
    if (token == null) return;
    await _send(token);
    _refreshSub?.cancel();
    _refreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(_send);
    _foregroundSub?.cancel();
    // A message arriving in the foreground just refreshes the inbox; text is generic by design.
    _foregroundSub = FirebaseMessaging.onMessage.listen(
      (_) => _ref.invalidate(notificationsProvider),
    );
  }

  Future<void> _send(String token) async {
    try {
      await _ref
          .read(apiClientProvider)
          .post(
            '/devices/register',
            body: {'token': token, 'platform': 'ANDROID'},
          );
    } catch (_) {
      // Retried on next sign-in / token refresh.
    }
  }
}

final pushRegistrarProvider = Provider<PushRegistrar>(
  (ref) => PushRegistrar(ref),
);
