import 'package:flutter/foundation.dart';

/// Configuración de la app inyectada en tiempo de compilación.
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.requestTimeout,
    required this.simulatorEnabled,
  });

  final String apiBaseUrl;
  final Duration requestTimeout;

  /// Habilita el simulador de condiciones de red (panel de desarrollador).
  final bool simulatorEnabled;

  /// URL definida explícitamente con `--dart-define=API_BASE_URL=...`.
  static const String definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Resuelve la URL del backend.
  ///
  /// Si no se definió `API_BASE_URL`, se adapta a la plataforma:
  /// - **Android** (emulador): `10.0.2.2` es el alias del host.
  /// - **iOS / macOS / otros**: el host es `localhost`.
  static String resolveBaseUrl({
    required String defined,
    required TargetPlatform platform,
  }) {
    if (defined.isNotEmpty) return defined;
    return platform == TargetPlatform.android
        ? 'http://10.0.2.2:8080'
        : 'http://localhost:8080';
  }

  static AppConfig get defaults => AppConfig(
        apiBaseUrl: resolveBaseUrl(
          defined: definedBaseUrl,
          platform: defaultTargetPlatform,
        ),
        requestTimeout: const Duration(seconds: 15),
        simulatorEnabled: const bool.fromEnvironment(
          'NETWORK_SIMULATOR',
          defaultValue: true,
        ),
      );
}
