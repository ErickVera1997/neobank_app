import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/notifications_repository.dart';

/// Estado del centro de notificaciones con actualización optimista.
class NotificationsController extends AsyncNotifier<NotificationsResult> {
  @override
  Future<NotificationsResult> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return const NotificationsResult(items: [], unreadCount: 0);
    }
    return ref.read(notificationsRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(notificationsRepositoryProvider).list(),
    );
  }

  Future<void> markRead(String id) async {
    final current = state.value;
    if (current == null) return;
    final wasUnread = current.items
        .any((item) => item.id == id && !item.read);
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
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsController, NotificationsResult>(
  NotificationsController.new,
);

/// Número de notificaciones sin leer (para el badge).
final unreadNotificationsProvider = Provider<int>(
  (ref) => ref.watch(notificationsProvider).value?.unreadCount ?? 0,
);
