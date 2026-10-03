import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neobank_core/neobank_core.dart';
import 'package:uuid/uuid.dart';

import '../../auth/application/auth_controller.dart';
import '../data/notifications_repository.dart';

/// Servicio de notificaciones.
///
/// En esta demo el "push" se materializa con notificaciones locales y con el
/// registro del dispositivo en el backend. El punto de extensión para push
/// remoto real (FCM/APNs) es `NotificationsRepository.registerDevice`: basta
/// enviar el token de FCM en lugar del token local.
class PushService {
  PushService(this._repository);

  final NotificationsRepository _repository;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<String?> initialize() async {
    if (_initialized) return null;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );
      await _requestPermissions();
      _initialized = true;
    } catch (_) {
      return null;
    }
    return 'local-${const Uuid().v4()}';
  }

  Future<void> registerDevice() async {
    final token = await initialize();
    if (token == null) return;
    try {
      await _repository.registerDevice(
        token: token,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
    } catch (_) {
      // Best-effort: no bloquear el flujo de la app.
    }
  }

  Future<void> show(AppNotification notification) async {
    if (!_initialized) return;
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'neobank_default',
          'Neobank',
          channelDescription: 'Notificaciones de tu cuenta',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );
      await _plugin.show(
        notification.id.hashCode,
        notification.title,
        notification.body,
        details,
      );
    } catch (_) {
      // Ignorar errores de presentación.
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }
}

final pushServiceProvider = Provider<PushService>(
  (ref) => PushService(ref.watch(notificationsRepositoryProvider)),
);

/// Registra el dispositivo una vez por sesión autenticada.
final pushRegistrationProvider = FutureProvider<void>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return;
  await ref.read(pushServiceProvider).registerDevice();
});
