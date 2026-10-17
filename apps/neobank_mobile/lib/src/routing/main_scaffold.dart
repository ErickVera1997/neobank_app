import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/notifications/application/notifications_controller.dart';
import '../shared/widgets/app_widgets.dart';

/// Shell principal con barra de navegación inferior y banner de conectividad.
class MainScaffold extends ConsumerWidget {
  const MainScaffold({
    required this.location,
    required this.child,
    super.key,
  });

  final String location;
  final Widget child;

  static const List<String> _routes = [
    '/home',
    '/accounts',
    '/fx',
    '/notifications',
    '/profile',
  ];

  int get _index {
    if (location.startsWith('/accounts')) return 1;
    if (location.startsWith('/fx')) return 2;
    if (location.startsWith('/notifications')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Consulta notificaciones nuevas en segundo plano (badge + aviso del SO).
    ref.watch(notificationsPollerProvider);
    final unread = ref.watch(unreadNotificationsProvider);

    // Aviso in-app de respaldo: garantiza feedback aunque el sistema operativo
    // no muestre el banner (p. ej. permiso denegado).
    ref.listen<int>(unreadNotificationsProvider, (previous, next) {
      if (previous != null && next > previous) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔔 Tienes una notificación nueva'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
    // En pestañas distintas a Inicio, el botón "atrás" de Android vuelve a
    // Inicio en lugar de cerrar la app.
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/home');
      },
      child: Scaffold(
        body: Column(
          children: [
            const ConnectivityBanner(),
            Expanded(child: child),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (index) => context.go(_routes[index]),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Inicio',
            ),
            const NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Cuentas',
            ),
            const NavigationDestination(
              icon: Icon(Icons.currency_exchange_outlined),
              selectedIcon: Icon(Icons.currency_exchange_rounded),
              label: 'Divisas',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(Icons.notifications_none_rounded),
              ),
              selectedIcon: const Icon(Icons.notifications_rounded),
              label: 'Alertas',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}
