import 'package:dio/dio.dart';

/// Categoría de error de la app, útil para decidir UI y si reintentar.
enum AppErrorKind {
  offline,
  timeout,
  network,
  unauthorized,
  notFound,
  conflict,
  validation,
  server,
  unknown,
}

/// Excepción de aplicación con mensaje apto para el usuario.
class AppException implements Exception {
  const AppException(this.kind, this.message, {this.code, this.statusCode});

  final AppErrorKind kind;
  final String message;
  final String? code;
  final int? statusCode;

  /// Si es probable que un reintento tenga éxito.
  bool get isRetryable =>
      kind == AppErrorKind.offline ||
      kind == AppErrorKind.timeout ||
      kind == AppErrorKind.network ||
      kind == AppErrorKind.server;

  factory AppException.fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const AppException(
          AppErrorKind.timeout,
          'La operación tardó demasiado. Reintenta.',
          code: 'timeout',
        );
      case DioExceptionType.connectionError:
        return const AppException(
          AppErrorKind.offline,
          'Sin conexión. Revisa tu red e inténtalo de nuevo.',
          code: 'offline',
        );
      case DioExceptionType.badCertificate:
        return const AppException(
          AppErrorKind.network,
          'No se pudo verificar la conexión segura.',
          code: 'bad_certificate',
        );
      case DioExceptionType.transformTimeout:
        return const AppException(
          AppErrorKind.timeout,
          'La operación tardó demasiado. Reintenta.',
          code: 'timeout',
        );
      case DioExceptionType.cancel:
        return const AppException(
          AppErrorKind.unknown,
          'Operación cancelada.',
          code: 'cancelled',
        );
      case DioExceptionType.badResponse:
        return AppException._fromResponse(error.response);
      case DioExceptionType.unknown:
        return AppException(
          AppErrorKind.network,
          'Error de red inesperado: ${error.message ?? 'desconocido'}',
          code: 'network_unknown',
        );
    }
  }

  factory AppException._fromResponse(Response<dynamic>? response) {
    final status = response?.statusCode ?? 0;
    final data = response?.data;
    String? message;
    String? code;
    if (data is Map) {
      message = data['message']?.toString();
      code = data['code']?.toString();
    }
    final kind = switch (status) {
      401 || 403 => AppErrorKind.unauthorized,
      404 => AppErrorKind.notFound,
      409 => AppErrorKind.conflict,
      400 || 422 => AppErrorKind.validation,
      >= 500 => AppErrorKind.server,
      _ => AppErrorKind.unknown,
    };
    return AppException(
      kind,
      message ?? _defaultMessage(kind),
      code: code,
      statusCode: status,
    );
  }

  static String _defaultMessage(AppErrorKind kind) => switch (kind) {
        AppErrorKind.unauthorized => 'Tu sesión expiró. Inicia sesión otra vez.',
        AppErrorKind.notFound => 'No encontramos lo que buscas.',
        AppErrorKind.conflict => 'La operación no se pudo completar.',
        AppErrorKind.validation => 'Revisa los datos ingresados.',
        AppErrorKind.server => 'El servicio no está disponible. Reintenta.',
        _ => 'Ocurrió un error inesperado.',
      };

  @override
  String toString() => 'AppException($kind, $statusCode): $message';
}
