import 'dart:io';

/// Configuración del backend, resuelta desde variables de entorno.
class AppConfig {
  const AppConfig({
    required this.port,
    required this.databasePath,
    required this.jwtSecret,
    required this.accessTokenTtl,
    required this.refreshTokenTtl,
    required this.otpTtl,
    required this.fxBaseUrl,
    required this.environment,
    this.pushWebhookUrl,
    this.fxTimeout = const Duration(seconds: 8),
  });

  final int port;

  /// Ruta del archivo SQLite o `:memory:` para pruebas.
  final String databasePath;
  final String jwtSecret;
  final Duration accessTokenTtl;
  final Duration refreshTokenTtl;
  final Duration otpTtl;
  final String fxBaseUrl;
  final Duration fxTimeout;
  final String environment;
  final String? pushWebhookUrl;

  bool get isDevelopment => environment == 'development';

  factory AppConfig.fromEnvironment([Map<String, String>? overrides]) {
    final env = overrides ?? Platform.environment;
    return AppConfig(
      port: int.tryParse(env['PORT'] ?? '') ?? 8080,
      databasePath: env['DB_PATH'] ?? 'data/neobank.sqlite',
      jwtSecret: env['JWT_SECRET'] ?? 'dev-secret-change-me',
      accessTokenTtl: const Duration(minutes: 30),
      refreshTokenTtl: const Duration(days: 30),
      otpTtl: const Duration(minutes: 5),
      fxBaseUrl: env['FX_BASE_URL'] ?? 'https://api.frankfurter.app',
      environment: env['ENV'] ?? 'development',
      pushWebhookUrl: env['PUSH_WEBHOOK_URL'],
    );
  }
}
