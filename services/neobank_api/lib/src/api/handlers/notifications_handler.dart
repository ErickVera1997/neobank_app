import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../app.dart';
import '../../domain/errors.dart';
import '../http_helpers.dart';
import '../middleware.dart';

/// Centro de notificaciones in-app.
class NotificationsHandler {
  const NotificationsHandler(this.app);

  final AppContainer app;

  Future<Response> list(Request request) async {
    final user = currentUser(request);
    final items = app.store.notificationsForUser(user.id);
    return jsonResponse({
      'items': items.map((item) => item.toJson()).toList(growable: false),
      'unreadCount': app.store.unreadNotificationCount(user.id),
    });
  }

  Future<Response> markRead(Request request) async {
    final user = currentUser(request);
    final id = request.params['id'] ?? '';
    final updated = app.store.markNotificationRead(id, user.id);
    if (!updated) {
      throw ApiException.notFound('Notificación no encontrada');
    }
    return noContent();
  }
}
