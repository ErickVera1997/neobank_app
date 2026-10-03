import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neobank_core/neobank_core.dart';

import '../../../core/providers.dart';
import '../data/auth_repository.dart';

/// Estado de autenticación: `null` significa sesión cerrada.
class AuthController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final tokens = await ref.read(tokenStoreProvider).read();
    if (tokens == null) return null;
    try {
      return await ref.read(authRepositoryProvider).currentUser();
    } catch (_) {
      return null;
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = await AsyncValue.guard(() async {
      final session = await ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
      return session.user;
    });
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? phone,
    String segment = 'standard',
  }) async {
    state = await AsyncValue.guard(() async {
      final session = await ref.read(authRepositoryProvider).register(
            name: name,
            email: email,
            password: password,
            phone: phone,
            segment: segment,
          );
      return session.user;
    });
  }

  Future<void> verifyOtp({
    required String challengeId,
    required String code,
  }) async {
    state = await AsyncValue.guard(() async {
      final session = await ref.read(authRepositoryProvider).verifyOtp(
            challengeId: challengeId,
            code: code,
          );
      return session.user;
    });
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, User?>(AuthController.new);

/// Identificador del usuario actual. Depender de él fuerza el refresco de los
/// datos de negocio cuando cambia la sesión.
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(authControllerProvider).value?.id,
);
