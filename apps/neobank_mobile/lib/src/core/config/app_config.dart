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

  /// Android emulator usa `10.0.2.2`; iOS simulator `localhost`.
  static const AppConfig defaults = AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8080',
    ),
    requestTimeout: Duration(seconds: 15),
    simulatorEnabled: bool.fromEnvironment(
      'NETWORK_SIMULATOR',
      defaultValue: true,
    ),
  );
}
