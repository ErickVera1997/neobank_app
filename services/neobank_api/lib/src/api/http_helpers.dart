import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import '../domain/errors.dart';

const Map<String, String> corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

/// Respuesta JSON uniforme.
Response jsonResponse(Object? body, {int status = 200}) => Response(
      status,
      body: body == null ? null : jsonEncode(body),
      headers: const {
        'Content-Type': 'application/json; charset=utf-8',
      },
    );

Response noContent() => Response(204);

/// Lee y valida un cuerpo JSON de la petición.
Future<Map<String, dynamic>> readJson(Request request) async {
  final raw = await request.readAsString();
  if (raw.trim().isEmpty) return <String, dynamic>{};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    throw ApiException.badRequest('El cuerpo debe ser un objeto JSON');
  } on FormatException {
    throw ApiException.badRequest('Cuerpo JSON inválido');
  }
}

/// Extrae el token Bearer del header `Authorization`.
String? bearerToken(Request request) {
  final header = request.headers['authorization'];
  if (header == null) return null;
  const prefix = 'bearer ';
  if (header.toLowerCase().startsWith(prefix)) {
    return header.substring(prefix.length).trim();
  }
  return null;
}

/// Responde a preflight CORS y añade cabeceras a todas las respuestas.
Middleware corsMiddleware() => (inner) => (request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: corsHeaders);
      }
      final response = await inner(request);
      return response.change(headers: corsHeaders);
    };

/// Convierte `ApiException` y errores inesperados en respuestas JSON.
Middleware errorMiddleware() => (inner) => (request) async {
      try {
        return await inner(request);
      } on ApiException catch (error) {
        return jsonResponse(
          {
            'code': error.code,
            'message': error.message,
            if (error.details != null) 'details': error.details,
          },
          status: error.statusCode,
        );
      } catch (error, stackTrace) {
        stderr.writeln('Unhandled error on ${request.method} '
            '${request.requestedUri.path}: $error\n$stackTrace');
        return jsonResponse(
          const {
            'code': 'internal_error',
            'message': 'Ocurrió un error interno',
          },
          status: 500,
        );
      }
    };
