import 'dart:async';

import 'package:neobank_core/neobank_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../app.dart';
import 'handlers/accounts_handler.dart';
import 'handlers/assistant_handler.dart';
import 'handlers/auth_handler.dart';
import 'handlers/config_handler.dart';
import 'handlers/fx_handler.dart';
import 'handlers/insights_handler.dart';
import 'handlers/notifications_handler.dart';
import 'http_helpers.dart';
import 'middleware.dart';

/// Rutas accesibles sin autenticación.
const List<String> _publicPrefixes = ['auth/'];

bool _isPublic(String path) {
  final normalized = path.startsWith('/') ? path.substring(1) : path;
  if (normalized == 'health') return true;
  return _publicPrefixes.any(normalized.startsWith);
}

Response _notFound(Request request) => jsonResponse(
      const {'code': 'not_found', 'message': 'Ruta no encontrada'},
      status: 404,
    );

Response _health(AppContainer app) => jsonResponse({
      'status': 'ok',
      'service': 'neobank_api',
      'version': '1.0.0',
      'environment': app.config.environment,
      'time': DateTime.now().toUtc().toIso8601String(),
    });

/// Construye el handler HTTP completo del backend.
Handler buildHandler(AppContainer app) {
  final auth = AuthHandler(app);
  final accounts = AccountsHandler(app);
  final devices = DevicesHandler(app);
  final fx = FxHandler(app);
  final config = ConfigHandler(app);
  final notifications = NotificationsHandler(app);
  final insights = InsightsHandler(app);
  final assistant = AssistantHandler(app);

  final publicRouter = Router(notFoundHandler: _notFound)
    ..get('/health', (Request request) => _health(app))
    ..post(ApiPaths.register, auth.register)
    ..post(ApiPaths.login, auth.login)
    ..post(ApiPaths.refresh, auth.refresh)
    ..post(ApiPaths.otpRequest, auth.requestOtp)
    ..post(ApiPaths.otpVerify, auth.verifyOtp);

  final protectedRouter = Router(notFoundHandler: _notFound)
    ..get(ApiPaths.me, auth.me)
    ..post(ApiPaths.logout, auth.logout)
    ..get(ApiPaths.accounts, accounts.list)
    ..get('/accounts/<id>', accounts.detail)
    ..get('/accounts/<id>/transactions', accounts.transactions)
    ..post(ApiPaths.transfers, accounts.transfer)
    ..get(ApiPaths.fxRates, fx.rates)
    ..post(ApiPaths.fxConvert, fx.convert)
    ..get(ApiPaths.bootstrap, config.bootstrap)
    ..get(ApiPaths.insights, insights.monthly)
    ..post(ApiPaths.assistant, assistant.ask)
    ..get(ApiPaths.notifications, notifications.list)
    ..post('/notifications/<id>/read', notifications.markRead)
    ..post(ApiPaths.devices, devices.register);

  final protectedHandler = const Pipeline()
      .addMiddleware(authMiddleware(app))
      .addHandler(protectedRouter.call);

  final publicHandler = publicRouter.call;

  FutureOr<Response> dispatch(Request request) => _isPublic(request.url.path)
      ? publicHandler(request)
      : protectedHandler(request);

  return const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsMiddleware())
      .addMiddleware(errorMiddleware())
      .addHandler(dispatch);
}
