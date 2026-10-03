import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neobank_core/neobank_core.dart';

import '../../../shared/widgets/app_widgets.dart';
import '../application/notifications_controller.dart';

/// Centro de notificaciones.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(notificationsProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
        child: AsyncValueView(
          value: async,
          onRetry: () => ref.read(notificationsProvider.notifier).refresh(),
          builder: (result) {
            if (result.items.isEmpty) {
              return const EmptyView(
                icon: Icons.notifications_off_outlined,
                title: 'Sin notificaciones',
                subtitle: 'Te avisaremos cuando pase algo importante.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: result.items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notification = result.items[index];
                return _NotificationTile(
                  notification: notification,
                  onTap: () => ref
                      .read(notificationsProvider.notifier)
                      .markRead(notification.id),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  IconData get _icon => switch (notification.type) {
        AppNotificationType.transaction => Icons.swap_horiz_rounded,
        AppNotificationType.security => Icons.shield_outlined,
        AppNotificationType.promo => Icons.local_offer_outlined,
        AppNotificationType.system => Icons.info_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: notification.read
            ? scheme.surfaceContainerHighest
            : scheme.primaryContainer,
        child: Icon(
          _icon,
          color: notification.read
              ? scheme.onSurfaceVariant
              : scheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: notification.read ? FontWeight.w500 : FontWeight.w700,
        ),
      ),
      subtitle: Text(notification.body),
      trailing: notification.read
          ? null
          : Icon(Icons.circle, size: 10, color: scheme.primary),
    );
  }
}
