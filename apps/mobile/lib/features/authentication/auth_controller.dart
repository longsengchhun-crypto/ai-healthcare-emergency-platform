import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/network/providers.dart';

class CurrentUser {
  CurrentUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.roles,
    required this.permissions,
  });

  factory CurrentUser.fromJson(Map<String, dynamic> j) => CurrentUser(
    id: j['id'] as String,
    email: j['email'] as String,
    fullName: (j['fullName'] as String?) ?? '',
    roles: List<String>.from(j['roles'] as List),
    permissions: List<String>.from(j['permissions'] as List),
  );

  final String id;
  final String email;
  final String fullName;
  final List<String> roles;
  final List<String> permissions;

  bool get isPatient => roles.contains('PATIENT');
  bool get isDoctor => roles.contains('DOCTOR');
  bool get isStaff =>
      roles.contains('HOSPITAL_STAFF') || roles.contains('SYSTEM_ADMIN');
  bool can(String permission) => permissions.contains(permission);
  String get firstName =>
      fullName.trim().isEmpty ? 'there' : fullName.trim().split(' ').first;
}

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  const AuthState(this.status, {this.user, this.sessionExpired = false});
  final AuthStatus status;
  final CurrentUser? user;
  final bool sessionExpired;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState(AuthStatus.unknown);

  Future<void> bootstrap() async {
    final tokens = ref.read(tokenStorageProvider);
    if (await tokens.readAccess() == null) {
      state = const AuthState(AuthStatus.unauthenticated);
      return;
    }
    try {
      await _loadUser();
    } on AppException catch (e) {
      if (e.kind == ErrorKind.offline || e.kind == ErrorKind.timeout) {
        // Keep the session; the user can retry once connectivity returns.
        state = const AuthState(AuthStatus.unauthenticated);
      } else {
        await tokens.clear();
        state = const AuthState(AuthStatus.unauthenticated);
      }
    }
  }

  Future<void> login(String email, String password) async {
    final res = await ref
        .read(apiClientProvider)
        .post(
          '/auth/login',
          body: {
            'email': email,
            'password': password,
            'deviceLabel': 'Android',
          },
          skipAuth: true,
        );
    await _acceptTokens(res as Map<String, dynamic>);
  }

  Future<void> register(
    String fullName,
    String email,
    String password,
    String? phone,
  ) async {
    final res = await ref
        .read(apiClientProvider)
        .post(
          '/auth/register',
          body: {
            'fullName': fullName,
            'email': email,
            'password': password,
            if (phone != null && phone.isNotEmpty) 'phone': phone,
            'deviceLabel': 'Android',
          },
          skipAuth: true,
        );
    await _acceptTokens(res as Map<String, dynamic>);
  }

  Future<void> logout() async {
    final tokens = ref.read(tokenStorageProvider);
    final refresh = await tokens.readRefresh();
    if (refresh != null) {
      try {
        await ref
            .read(apiClientProvider)
            .post('/auth/logout', body: {'refreshToken': refresh});
      } catch (_) {
        // Best effort: local credentials are cleared regardless.
      }
    }
    await tokens.clear();
    state = const AuthState(AuthStatus.unauthenticated);
  }

  void sessionExpired() {
    if (state.status == AuthStatus.authenticated) {
      state = const AuthState(AuthStatus.unauthenticated, sessionExpired: true);
    }
  }

  Future<void> _acceptTokens(Map<String, dynamic> res) async {
    await ref
        .read(tokenStorageProvider)
        .save(
          access: res['accessToken'] as String,
          refresh: res['refreshToken'] as String,
        );
    await _loadUser();
  }

  Future<void> _loadUser() async {
    final me = await ref.read(apiClientProvider).get('/users/me');
    state = AuthState(
      AuthStatus.authenticated,
      user: CurrentUser.fromJson(me as Map<String, dynamic>),
    );
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
