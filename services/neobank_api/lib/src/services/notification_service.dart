import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:neobank_core/neobank_core.dart';
import 'package:uuid/uuid.dart';

import '../data/store.dart';

/// Punto de integración con un proveedor de push (FCM/APNs o un servicio
/// propio). Se define como interfaz para poder sustituirlo en pruebas.
abstract interface class PushGateway {
  Future<void> send({
    required List<String> tokens,
    required AppNotification notification,
  });
}

/// Implementación por defecto: sólo persiste la notificación in-app.
class NoopPushGateway implements PushGateway {
  const NoopPushGateway();

  @override
  Future<void> send({
    required List<String> tokens,
    required AppNotification notification,
  }) async {}
}

/// Envía la notificación a un webhook real (p. ej. un relay hacia FCM/APNs).
class WebhookPushGateway implements PushGateway {
  WebhookPushGateway({
    required this.url,
    http.Client? client,
    this.timeout = const Duration(seconds: 5),
  }) : _client = client ?? http.Client();

  final String url;
  final Duration timeout;
  final http.Client _client;

  @override
  Future<void> send({
    required List<String> tokens,
    required AppNotification notification,
  }) async {
    try {
      await _client
          .post(
            Uri.parse(url),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'tokens': tokens,
              'notification': notification.toJson(),
            }),
          )
          .timeout(timeout);
    } catch (_) {
      // El push es best-effort: nunca debe tumbar la operación financiera.
    }
  }
}

/// Genera notificaciones in-app al ocurrir eventos y las reenvía al proveedor.
class NotificationService {
  NotificationService(this._store, {PushGateway? gateway})
      : _gateway = gateway ?? const NoopPushGateway();

  final Store _store;
  final PushGateway _gateway;

  Future<AppNotification> onTransaction({
    required String userId,
    required BankTransaction transaction,
    required String accountAlias,
  }) async {
    final isCredit = transaction.isCredit;
    final notification = AppNotification(
      id: const Uuid().v4(),
      title: isCredit ? 'Recibiste un abono' : 'Se realizó un pago',
      body:
          '${isCredit ? '+' : '-'}${transaction.amount.abs().format()} · ${transaction.description}',
      type: AppNotificationType.transaction,
      createdAt: DateTime.now(),
      data: {
        'accountId': transaction.accountId,
        'accountAlias': accountAlias,
        'transactionId': transaction.id,
      },
    );
    _store.insertNotification(
      id: notification.id,
      userId: userId,
      title: notification.title,
      body: notification.body,
      type: notification.type,
      data: notification.data,
      createdAt: notification.createdAt,
    );
    final tokens = _store.deviceTokensForUser(userId);
    if (tokens.isNotEmpty) {
      await _gateway.send(tokens: tokens, notification: notification);
    }
    return notification;
  }

  Future<void> notifySecurity({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    final notification = AppNotification(
      id: const Uuid().v4(),
      title: title,
      body: body,
      type: AppNotificationType.security,
      createdAt: DateTime.now(),
      data: data,
    );
    _store.insertNotification(
      id: notification.id,
      userId: userId,
      title: title,
      body: body,
      type: AppNotificationType.security,
      data: data,
      createdAt: notification.createdAt,
    );
    final tokens = _store.deviceTokensForUser(userId);
    if (tokens.isNotEmpty) {
      await _gateway.send(tokens: tokens, notification: notification);
    }
  }
}
