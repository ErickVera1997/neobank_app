import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neobank_core/neobank_core.dart';
import 'package:neobank_mobile/src/core/providers.dart';
import 'package:neobank_mobile/src/core/storage/token_store.dart';
import 'package:neobank_mobile/src/features/auth/application/auth_controller.dart';
import 'package:neobank_mobile/src/features/auth/data/auth_repository.dart';
import 'package:neobank_mobile/src/features/auth/presentation/login_screen.dart';

/// Repositorio falso para probar el flujo sin backend.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.shouldFail = false});

  final bool shouldFail;

  @override
  Future<User> currentUser() async => throw UnimplementedError();

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    if (shouldFail) throw Exception('credenciales inválidas');
    return AuthSession(
      user: User(
        id: 'u1',
        name: 'Ana Torres',
        email: email,
        segment: UserSegment.premium,
        createdAt: DateTime(2026, 1, 1),
      ),
      tokens: const AuthTokens(
        accessToken: 'a',
        refreshToken: 'r',
        expiresIn: 900,
      ),
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
    String? phone,
    String segment = 'standard',
  }) async =>
      throw UnimplementedError();

  @override
  Future<OtpChallenge> requestOtp(String email) async =>
      throw UnimplementedError();

  @override
  Future<AuthSession> verifyOtp({
    required String challengeId,
    required String code,
  }) async =>
      throw UnimplementedError();
}

void main() {
  testWidgets('LoginScreen valida campos vacíos', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.enterText(find.byType(TextFormField).last, '');
    await tester.tap(find.text('Ingresar'));
    await tester.pump();

    expect(find.text('Ingresa un email válido'), findsOneWidget);
    expect(find.text('Mínimo 8 caracteres'), findsOneWidget);
  });

  testWidgets('AuthController pasa a autenticado tras el login',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(authControllerProvider.future), isNull);

    await container
        .read(authControllerProvider.notifier)
        .login(email: 'ana@neobank.com', password: 'Password123');

    final user = container.read(authControllerProvider).value;
    expect(user?.email, 'ana@neobank.com');
    expect(user?.segment, UserSegment.premium);
  });

  testWidgets('AuthController expone error con credenciales inválidas',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider
            .overrideWithValue(_FakeAuthRepository(shouldFail: true)),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(authControllerProvider.notifier)
        .login(email: 'ana@neobank.com', password: 'mala');

    expect(container.read(authControllerProvider).hasError, isTrue);
  });
}