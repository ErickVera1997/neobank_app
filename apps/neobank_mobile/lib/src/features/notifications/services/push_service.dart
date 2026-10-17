import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neobank_core/neobank_core.dart';
import 'package:uuid/uuid.dart';

import '../../auth/application/auth_controller.dart';
import '../data/notifications_repository.dart';

/// Notificaciones locales del sistema operativo.
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
  bool _permissionGranted = false;

  /// Resultado de la solicitud de permiso (útil para diagnósticos).
  bool get permissionGranted => _permissionGranted;

  Future<String?> initialize() async {
    if (_initialized) return null;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        // Presentación en primer plano (iOS 14+): banner + centro de
        // notificaciones. Sin esto, iOS descarta el aviso si la app está abierta.
        defaultPresentAlert: true,
        defaultPresentBanner: true,
        defaultPresentList: true,
      );
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );
      await _requestPermissions();
      _initialized = true;
    } catch (error) {
      debugPrint('PushService: no se pudo inicializar ($error)');
      return null;
    }
    return 'local-${const Uuid().v4()}';
  }

  /// Fuerza la solicitud de permisos (por si se denegó y el usuario cambia de
  /// opinión en Ajustes).
  Future<bool> requestPermissions() async {
    await initialize();
    return _permissionGranted;
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
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          presentBanner: true,
          presentList: true,
        ),
      );
      await _plugin.show(
        notification.id.hashCode,
        notification.title,
        notification.body,
        details,
      );
    } catch (error) {
      debugPrint('PushService: no se pudo mostrar la notificación ($error)');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        _permissionGranted =
            await android?.requestNotificationsPermission() ?? false;
        debugPrint(
          'PushService: permiso de notificaciones (Android) = $_permissionGranted',
        );
      } else if (Platform.isIOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        _permissionGranted = await ios?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
        debugPrint(
          'PushService: permiso de notificaciones (iOS) = $_permissionGranted',
        );
      }
    } catch (error) {
      debugPrint('PushService: error al pedir permisos ($error)');
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