import 'package:neobank_core/neobank_core.dart';
import 'package:shelf/shelf.dart';

import '../app.dart';
import 'http_helpers.dart';

/// Clave de contexto donde se inyecta el usuario autenticado.
const String userContextKey = 'neobank.user';

/// Valida el access token JWT y resuelve el usuario.
Middleware authMiddleware(AppContainer app) => (inner) => (request) async {
      final token = bearerToken(request);
      if (token == null) {
        return jsonResponse(
          const {
            'code': 'unauthorized',
            'message': 'Falta el token de acceso',
          },
          status: 401,
        );
      }
      final userId = app.tokens.verifyAccessToken(token);
      if (userId == null) {
        return jsonResponse(
          const {
            'code': 'unauthorized',
            'message': 'Token inválido o expirado',
          },
          status: 401,
        );
      }
      final record = app.store.findUserById(userId);
      if (record == null) {
        return jsonResponse(
          const {
            'code': 'unauthorized',
            'message': 'Usuario no encontrado',
          },
          status: 401,
        );
      }
      return inner(request.change(context: {userContextKey: record.user}));
    };

/// Recupera el usuario autenticado desde el contexto de la petición.
User currentUser(Request request) => request.context[userContextKey] as User;
