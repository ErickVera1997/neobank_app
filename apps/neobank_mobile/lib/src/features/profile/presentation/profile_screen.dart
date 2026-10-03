import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../accounts/application/accounts_controller.dart';
import '../../auth/application/auth_controller.dart';
import '../../config/application/bootstrap_controller.dart';
import '../../notifications/application/notifications_controller.dart';

/// Perfil del cliente y ajustes de la sesión.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final bucket = ref.watch(experimentBucketProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      user.firstName.characters.first.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(user.email,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Chip(
                    avatar: const Icon(Icons.workspace_premium_outlined,
                        size: 18),
                    label: Text('Segmento ${user.segment.name}'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Column(
                children: [
                  _InfoTile(
                    icon: Icons.phone_outlined,
                    label: 'Teléfono',
                    value: user.phone ?? 'No registrado',
                  ),
                  _InfoTile(
                    icon: Icons.badge_outlined,
                    label: 'Documento',
                    value: user.documentId ?? 'No registrado',
                  ),
                  _InfoTile(
                    icon: Icons.science_outlined,
                    label: 'Experimento',
                    value: bucket == null ? 'Sin asignar' : 'Variante $bucket',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.wifi_tethering_rounded),
                    title: const Text('Simulador de red'),
                    subtitle: const Text('Prueba offline, latencia y fallos'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.go('/settings'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.cleaning_services_outlined),
                    title: const Text('Limpiar caché local'),
                    onTap: () async {
                      await ref.read(apiClientProvider).clearCache();
                      ref.invalidate(accountsSummaryProvider);
                      ref.invalidate(bootstrapProvider);
                      ref.invalidate(notificationsProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Caché eliminada')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _confirmLogout(context, ref),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Cerrar sesión'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres salir de tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(value),
      );
}
