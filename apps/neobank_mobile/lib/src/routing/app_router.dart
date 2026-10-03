import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/accounts/presentation/account_detail_screen.dart';
import '../features/accounts/presentation/accounts_screen.dart';
import '../features/assistant/presentation/assistant_screen.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/otp_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/fx/presentation/fx_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/insights/presentation/insights_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/settings/presentation/network_simulator_screen.dart';
import '../features/transfers/presentation/transfer_screen.dart';
import 'main_scaffold.dart';

/// Adapta los cambios de estado de auth a `GoRouter.refreshListenable`.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (previous, next) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      final onSplash = location == '/splash';
      final onAuthFlow = location == '/login' ||
          location == '/register' ||
          location == '/otp';

      if (auth.isLoading && !auth.hasValue) {
        return onSplash ? null : '/splash';
      }
      final signedIn = auth.value != null;
      if (!signedIn) {
        return onAuthFlow ? null : '/login';
      }
      if (onAuthFlow || onSplash) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/otp', builder: (_, __) => const OtpScreen()),
      ShellRoute(
        builder: (context, state, child) => MainScaffold(
          location: state.matchedLocation,
          child: child,
        ),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/accounts', builder: (_, __) => const AccountsScreen()),
          GoRoute(path: '/fx', builder: (_, __) => const FxScreen()),
          GoRoute(
            path: '/notifications',
            builder: (_, __) => const NotificationsScreen(),
          ),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/accounts/:id',
        builder: (_, state) => AccountDetailScreen(
          accountId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(path: '/transfer', builder: (_, __) => const TransferScreen()),
      GoRoute(
        path: '/assistant',
        builder: (_, state) => AssistantScreen(
          initialPrompt: state.uri.queryParameters['q'],
        ),
      ),
      GoRoute(path: '/insights', builder: (_, __) => const InsightsScreen()),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const NetworkSimulatorScreen(),
      ),
    ],
  );
});
