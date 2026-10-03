import 'package:http/http.dart' as http;

import 'config.dart';
import 'data/database.dart';
import 'data/seed.dart';
import 'data/store.dart';
import 'security/password_hasher.dart';
import 'security/token_service.dart';
import 'services/fx_service.dart';
import 'services/notification_service.dart';

/// Contenedor de dependencias del backend.
///
/// Centraliza la construcción de infraestructura para que tanto el servidor
/// real como las pruebas de integración usen exactamente la misma composición.
class AppContainer {
  AppContainer._({
    required this.config,
    required this.database,
    required this.store,
    required this.tokens,
    required this.hasher,
    required this.fx,
    required this.notifications,
    required this.httpClient,
    required this.ownsHttpClient,
  });

  final AppConfig config;
  final AppDatabase database;
  final Store store;
  final TokenService tokens;
  final PasswordHasher hasher;
  final FxService fx;
  final NotificationService notifications;
  final http.Client httpClient;
  final bool ownsHttpClient;

  factory AppContainer.create(
    AppConfig config, {
    http.Client? httpClient,
    bool seed = true,
  }) {
    final database = AppDatabase.open(config.databasePath);
    final store = Store(database);
    final hasher = PasswordHasher();
    if (seed) {
      SeedData(store, hasher).ensure();
    }
    final tokens = TokenService(
      secret: config.jwtSecret,
      accessTokenTtl: config.accessTokenTtl,
      refreshTokenTtl: config.refreshTokenTtl,
    );
    final client = httpClient ?? http.Client();
    final fx = FxService(
      store,
      config.fxBaseUrl,
      client: client,
      timeout: config.fxTimeout,
    );
    final gateway = config.pushWebhookUrl == null
        ? const NoopPushGateway()
        : WebhookPushGateway(url: config.pushWebhookUrl!, client: client);
    final notifications = NotificationService(store, gateway: gateway);
    return AppContainer._(
      config: config,
      database: database,
      store: store,
      tokens: tokens,
      hasher: hasher,
      fx: fx,
      notifications: notifications,
      httpClient: client,
      ownsHttpClient: httpClient == null,
    );
  }

  void dispose() {
    if (ownsHttpClient) {
      httpClient.close();
    }
    database.close();
  }
}
