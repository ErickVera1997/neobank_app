/// Errores de dominio del backend con un código estable para el cliente.
class ApiException implements Exception {
  ApiException(this.statusCode, this.code, this.message, {this.details});

  final int statusCode;
  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => 'ApiException($statusCode $code): $message';

  factory ApiException.badRequest(String message, {String code = 'bad_request'}) =>
      ApiException(400, code, message);

  factory ApiException.unauthorized([String message = 'No autenticado']) =>
      ApiException(401, 'unauthorized', message);

  factory ApiException.forbidden([String message = 'Acceso denegado']) =>
      ApiException(403, 'forbidden', message);

  factory ApiException.notFound([String message = 'Recurso no encontrado']) =>
      ApiException(404, 'not_found', message);

  factory ApiException.conflict(String message) =>
      ApiException(409, 'conflict', message);

  factory ApiException.unavailable([String message = 'Servicio no disponible']) =>
      ApiException(503, 'service_unavailable', message);
}
