import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neobank_core/neobank_core.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';

/// Lista de notificaciones con conteo de no leídas.
class NotificationsResult {
  const NotificationsResult({
    required this.items,
    required this.unreadCount,
  });

  final List<AppNotification> items;
  final int unreadCount;

  NotificationsResult copyWith({
    List<AppNotification>? items,
    int? unreadCount,
  }) =>
      NotificationsResult(
        items: items ?? this.items,
        unreadCount: unreadCount ?? this.unreadCount,
      );
}

/// Acceso al centro de notificaciones y registro de dispositivos.
class NotificationsRepository {
  NotificationsRepository(this._client);

  final ApiClient _client;

  Future<NotificationsResult> list() async {
    final result = await _client.getJson(
      ApiPaths.notifications,
      cacheKey: 'notifications',
    );
    final items = (result.data['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList(growable: false);
    return NotificationsResult(
      items: items,
      unreadCount: (result.data['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> markRead(String id) =>
      _client.postVoid('/notifications/$id/read');

  Future<void> registerDevice({
    required String token,
    required String platform,
  }) =>
      _client.postVoid(
        ApiPaths.devices,
        body: {'token': token, 'platform': platform},
      );
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(apiClientProvider)),
);
