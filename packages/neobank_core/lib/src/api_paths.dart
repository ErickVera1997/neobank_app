/// Rutas de la API de Neobank, centralizadas para evitar strings mágicos.
abstract final class ApiPaths {
  static const String health = '/health';

  // Autenticación
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String otpRequest = '/auth/otp/request';
  static const String otpVerify = '/auth/otp/verify';
  static const String me = '/me';

  // Cuentas y movimientos
  static const String accounts = '/accounts';
  static String account(String id) => '/accounts/$id';
  static String accountTransactions(String id, {String? cursor}) {
    final base = '/accounts/$id/transactions';
    return cursor == null ? base : '$base?cursor=$cursor';
  }

  static const String transfers = '/transfers';

  // FX (micro-app de divisas)
  static const String fxRates = '/fx/rates';
  static const String fxConvert = '/fx/convert';

  // Personalización / configuración remota
  static const String bootstrap = '/config/bootstrap';
  static const String notifications = '/notifications';
  static String notificationRead(String id) => '/notifications/$id/read';

  // Analítica y asistencia
  static const String insights = '/insights';
  static const String assistant = '/assistant';

  // Dispositivos / push
  static const String devices = '/devices';
}
