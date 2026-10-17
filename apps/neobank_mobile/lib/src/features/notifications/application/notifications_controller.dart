import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/notifications_repository.dart';
import '../services/push_service.dart';

/// Cada cuánto se consultan notificaciones nuevas en segundo plano.
///
/// Es un *fallback* de demo sin credenciales. En producción se reemplaza por
/// push real (FCM/APNs) y/o un canal en tiempo real (ver `docs/operations.md`).
const Duration notificationsPollInterval = Duration(seconds: 20);

/// Estado del centro de notificaciones con actualización optimista y
/// detección de novedades para notificar al sistema operativo.
class NotificationsController extends AsyncNotifier<NotificationsResult> {
  final Set<String> _seenIds = <String>{};
  String? _primedForUserId;

  @override
  Future<NotificationsResult> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      _seenIds.clear();
      _primedForUserId = null;
      return const NotificationsResult(items: [], unreadCount: 0);
    }
    final result = await ref.read(notificationsRepositoryProvider).list();
    _sync(userId, result);
    return result;
  }

  /// Refresco silencioso en segundo plano: no muestra spinners ni propaga
  /// errores (un fallo de red no debe romper la experiencia).
  Future<void> poll() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      final result = await ref.read(notificationsRepositoryProvider).list();
      _sync(userId, result);
      state = AsyncData(result);
    } catch (_) {
      // Silencioso a propósito.
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await ref.read(notificationsRepositoryProvider).list();
      _sync(ref.read(currentUserIdProvider), result);
      return result;
    });
  }

  Future<void> markRead(String id) async {
    final current = state.value;
    if (current == null) return;
    final wasUnread =
        current.items.any((item) => item.id == id && !item.read);
    state = AsyncData(
      current.copyWith(
        items: current.items
            .map((item) => item.id == id ? item.copyWith(read: true) : item)
            .toList(growable: false),
        unreadCount:
            wasUnread ? max(0, current.unreadCount - 1) : current.unreadCount,
      ),
    );
    try {
      await ref.read(notificationsRepositoryProvider).markRead(id);
    } catch (_) {
      state = AsyncData(current);
    }
  }

  /// En la primera carga (o al cambiar de usuario) marca lo existente como
  /// visto sin notificar. En cargas posteriores, cada id nuevo dispara una
  /// notificación local del sistema operativo.
  void _sync(String? userId, NotificationsResult result) {
    if (_primedForUserId != userId) {
      _seenIds
        ..clear()
        ..addAll(result.items.map((item) => item.id));
      _primedForUserId = userId;
      return;
    }
    for (final item in result.items) {
      if (_seenIds.add(item.id)) {
        ref.read(pushServiceProvider).show(item);
      }
    }
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsController, NotificationsResult>(
  NotificationsController.new,
);

/// Número de notificaciones sin leer (para el badge).
final unreadNotificationsProvider = Provider<int>(
  (ref) => ref.watch(notificationsProvider).value?.unreadCount ?? 0,
);

/// Consulta notificaciones nuevas periódicamente mientras hay sesión.
///
/// Se mantiene activo mientras la app autenticada está montada (shell); se
/// cancela automáticamente al cerrar sesión.
final notificationsPollerProvider = Provider<void>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return;
  final timer = Timer.periodic(notificationsPollInterval, (_) {
    ref.read(notificationsProvider.notifier).poll();
  });
  ref.onDispose(timer.cancel);
});