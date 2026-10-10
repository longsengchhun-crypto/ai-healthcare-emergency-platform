enum ErrorKind {
  offline,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  validation,
  conflict,
  rateLimited,
  server,
  unknown,
}

/// A user-presentable failure. Messages are safe to show and never contain secrets.
class AppException implements Exception {
  AppException(this.kind, this.message, {this.code, this.fields});

  final ErrorKind kind;
  final String message;
  final String? code;
  final Map<String, String>? fields;

  bool get isRetryable =>
      kind == ErrorKind.offline ||
      kind == ErrorKind.timeout ||
      kind == ErrorKind.server;

  @override
  String toString() => 'AppException($kind, $message)';
}

String describeError(Object error) {
  if (error is AppException) return error.message;
  return 'Something went wrong. Please try again.';
}
