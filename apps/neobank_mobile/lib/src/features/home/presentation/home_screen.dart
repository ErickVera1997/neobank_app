import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neobank_core/neobank_core.dart';

import '../../../shared/widgets/app_widgets.dart';
import '../../accounts/application/accounts_controller.dart';
import '../../auth/application/auth_controller.dart';
import '../../config/application/bootstrap_controller.dart';
import '../../notifications/application/notifications_controller.dart';
import '../../notifications/services/push_service.dart';
import 'home_modules.dart';

/// Home dinámico: el backend define qué módulos se muestran y en qué orden.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Registra el dispositivo para notificaciones al entrar con sesión.
    ref.watch(pushRegistrationProvider);

    final bootstrap = ref.watch(bootstrapProvider);
    final modules = ref.watch(homeModulesProvider);
    final user = ref.watch(authControllerProvider).value;
    final unread = ref.watch(unreadNotificationsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(bootstrapProvider.notifier).refresh();
            ref.invalidate(accountsSummaryProvider);
          },
          child: AsyncValueView(
            value: bootstrap,
            onRetry: () => ref.read(bootstrapProvider.notifier).refresh(),
            builder: (_) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _HomeHeader(
                  name: user?.firstName ?? 'Hola',
                  unread: unread,
                ),
                const SizedBox(height: 16),
                for (final module in modules) ...[
                  _buildModule(module),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModule(HomeModule module) {
    if (!module.enabled) return const SizedBox.shrink();
    return switch (module.type) {
      HomeModuleType.heroBalance => HeroBalanceModule(module: module),
      HomeModuleType.quickActions => QuickActionsModule(module: module),
      HomeModuleType.fxWidget => FxWidgetModule(module: module),
      HomeModuleType.offersCarousel => OffersModule(module: module),
      HomeModuleType.insights => InsightsModule(module: module),
      HomeModuleType.promo => PromoModule(module: module),
      HomeModuleType.custom => const SizedBox.shrink(),
    };
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.name, required this.unread});

  final String name;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: scheme.primaryContainer,
          child: Text(
            name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
            style: TextStyle(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hola, $name',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                'Este es tu resumen de hoy',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => context.go('/notifications'),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const Icon(Icons.notifications_none_rounded),
          ),
        ),
        IconButton(
          onPressed: () => context.go('/profile'),
          icon: const Icon(Icons.person_outline_rounded),
        ),
      ],
    );
  }
}
