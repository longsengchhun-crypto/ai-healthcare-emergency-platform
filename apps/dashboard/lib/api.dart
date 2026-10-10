import 'package:dio/dio.dart';

/// Failure with a safe, displayable message.
class ApiFailure implements Exception {
  ApiFailure(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}

/// Dashboard API client. The dashboard talks only to the secured backend API (never to the database).
/// Tokens are kept in memory only, so closing the tab ends the session.
class Api {
  Api(String baseUrl)
    : _dio = Dio(
        BaseOptions(
          baseUrl: '$baseUrl/api/v1',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

  final Dio _dio;
  String? _access;
  String? _refresh;
  void Function()? onSignedOut;
  Map<String, dynamic>? me;

  bool get signedIn => _access != null;

  Future<void> login(String email, String password) async {
    final res = await _request(
      () => _dio.post<dynamic>(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
          'deviceLabel': 'Dashboard',
        },
      ),
    );
    _access = res['accessToken'] as String;
    _refresh = res['refreshToken'] as String;
    me = Map<String, dynamic>.from(await get('/users/me') as Map);
    final roles = List<String>.from(me!['roles'] as List);
    if (!roles.contains('HOSPITAL_STAFF') &&
        !roles.contains('SYSTEM_ADMIN') &&
        !roles.contains('DOCTOR')) {
      await logout();
      throw ApiFailure(
        'This dashboard is for hospital staff and administrators.',
      );
    }
  }

  Future<void> logout() async {
    final refresh = _refresh;
    _access = null;
    _refresh = null;
    me = null;
    if (refresh != null) {
      try {
        await _dio.post<dynamic>(
          '/auth/logout',
          data: {'refreshToken': refresh},
        );
      } catch (_) {}
    }
    onSignedOut?.call();
  }

  bool can(String permission) =>
      List<String>.from((me?['permissions'] as List?) ?? const [])
          .contains(permission);

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) => _request(
    () => _dio.get<dynamic>(path, queryParameters: query, options: _auth()),
  );

  Future<dynamic> post(String path, {Object? body}) => _request(
    () => _dio.post<dynamic>(path, data: body ?? {}, options: _auth()),
  );

  Future<dynamic> put(String path, {Object? body}) =>
      _request(() => _dio.put<dynamic>(path, data: body, options: _auth()));

  Future<dynamic> patch(String path, {Object? body}) =>
      _request(() => _dio.patch<dynamic>(path, data: body, options: _auth()));

  Options _auth() => Options(headers: {'Authorization': 'Bearer $_access'});

  Future<dynamic> _request(Future<Response<dynamic>> Function() call) async {
    try {
      return (await call()).data;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 && _access != null) {
        _access = null;
        onSignedOut?.call();
        throw ApiFailure(
          'Your session expired. Please sign in again.',
          status: 401,
        );
      }
      if (e.type == DioExceptionType.connectionError) {
        throw ApiFailure('The server is unreachable.');
      }
      final body = e.response?.data;
      final message = body is Map ? body['message'] as String? : null;
      throw ApiFailure(switch (status) {
        403 => 'You do not have permission for this action.',
        429 => 'Too many attempts. Please wait a moment.',
        final s? when s >= 500 =>
          'The service is having trouble. Try again shortly.',
        _ => message ?? 'Request failed.',
      }, status: status);
    }
  }
}
