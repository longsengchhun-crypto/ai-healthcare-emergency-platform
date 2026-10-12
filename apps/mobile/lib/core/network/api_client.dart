import 'dart:async';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../errors/app_exception.dart';
import '../storage/token_storage.dart';

/// Thin HTTP layer over the secured backend. Responsibilities:
///  * attach the access token,
///  * transparently refresh it once on 401 (single flight, rotating refresh token),
///  * translate every failure into an [AppException] with a safe, human message.
class ApiClient {
  ApiClient({
    required TokenStorage tokens,
    required this.onSessionExpired,
    Dio? dio,
    String? baseUrl,
  }) : _tokens = tokens, // ignore: prefer_initializing_formals
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: '${baseUrl ?? AppConfig.apiBaseUrl}/api/v1',
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 35),
               sendTimeout: const Duration(seconds: 20),
               contentType: Headers.jsonContentType,
             ),
           ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['skipAuth'] != true) {
            final token = await _tokens.readAccess();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          final isAuthCall = request.extra['skipAuth'] == true;
          if (error.response?.statusCode == 401 &&
              !isAuthCall &&
              request.extra['retried'] != true) {
            final refreshed = await _refreshOnce();
            if (refreshed) {
              request.extra['retried'] = true;
              try {
                final token = await _tokens.readAccess();
                request.headers['Authorization'] = 'Bearer $token';
                return handler.resolve(await _dio.fetch(request));
              } on DioException catch (e) {
                return handler.next(e);
              }
            }
            onSessionExpired();
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final TokenStorage _tokens;
  final void Function() onSessionExpired;
  Completer<bool>? _refreshing;

  Future<bool> _refreshOnce() {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight.future;
    final completer = _refreshing = Completer<bool>();
    () async {
      try {
        final refresh = await _tokens.readRefresh();
        if (refresh == null) return completer.complete(false);
        final res = await _dio.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: {'refreshToken': refresh},
          options: Options(extra: {'skipAuth': true}),
        );
        final data = res.data!;
        await _tokens.save(
          access: data['accessToken'] as String,
          refresh: data['refreshToken'] as String,
        );
        completer.complete(true);
      } catch (_) {
        await _tokens.clear();
        completer.complete(false);
      } finally {
        _refreshing = null;
      }
    }();
    return completer.future;
  }

  Future<T> _run<T>(Future<Response<dynamic>> Function() call) async {
    try {
      final res = await call();
      return res.data as T;
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _run(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
    bool skipAuth = false,
  }) => _run(
    () => _dio.post<dynamic>(
      path,
      data: body,
      options: Options(headers: headers, extra: {'skipAuth': skipAuth}),
    ),
  );

  Future<dynamic> patch(String path, {Object? body}) =>
      _run(() => _dio.patch<dynamic>(path, data: body));

  Future<dynamic> put(String path, {Object? body}) =>
      _run(() => _dio.put<dynamic>(path, data: body));

  Future<dynamic> delete(String path) => _run(() => _dio.delete<dynamic>(path));

  Future<dynamic> upload(
    String path, {
    required String filename,
    required List<int> bytes,
    Map<String, String>? fields,
  }) => _run(
    () => _dio.post<dynamic>(
      path,
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
        ...?fields,
      }),
      options: Options(contentType: 'multipart/form-data'),
    ),
  );

  AppException _translate(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
        return AppException(
          ErrorKind.offline,
          'You appear to be offline or the server is unreachable.',
        );
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppException(
          ErrorKind.timeout,
          'The request timed out. Please try again.',
        );
      default:
        break;
    }
    final status = e.response?.statusCode ?? 0;
    final body = e.response?.data;
    String? message;
    String? code;
    Map<String, String>? fields;
    if (body is Map<String, dynamic>) {
      message = body['message'] as String?;
      code = body['code'] as String?;
      final f = body['fields'];
      if (f is Map) {
        fields = f.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    }
    switch (status) {
      case 400:
      case 422:
        return AppException(
          ErrorKind.validation,
          message ?? 'Please check the information you entered.',
          code: code,
          fields: fields,
        );
      case 401:
        return AppException(
          ErrorKind.unauthorized,
          message ?? 'Please sign in again.',
          code: code,
        );
      case 403:
        return AppException(
          ErrorKind.forbidden,
          'You do not have permission to do that.',
          code: code,
        );
      case 404:
        return AppException(
          ErrorKind.notFound,
          message ?? 'Not found.',
          code: code,
        );
      case 409:
        return AppException(
          ErrorKind.conflict,
          message ?? 'That conflicts with the current state.',
          code: code,
        );
      case 429:
        return AppException(
          ErrorKind.rateLimited,
          'Too many attempts. Please wait a moment and try again.',
        );
      default:
        if (status >= 500) {
          return AppException(
            ErrorKind.server,
            'The service is having trouble. Please try again shortly.',
          );
        }
        return AppException(ErrorKind.unknown, 'Something went wrong.');
    }
  }
}
