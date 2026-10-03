import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neobank_core/neobank_core.dart';
import 'package:neobank_mobile/src/features/auth/application/auth_controller.dart';
import 'package:neobank_mobile/src/features/config/application/bootstrap_controller.dart';
import 'package:neobank_mobile/src/features/config/data/config_repository.dart';

class _GuestAuth extends AuthController {
  @override
  Future<User?> build() async => null;
}

class _SessionAuth extends AuthController {
  @override
  Future<User?> build() async => User(
        id: 'u_demo',
        name: 'Ana Torres',
        email: 'ana@neobank.com',
        segment: UserSegment.premium,
        createdAt: DateTime(2026, 1, 1),
      );
}

class _CountingConfigRepository implements ConfigRepository {
  _CountingConfigRepository(this.onCall);

  final void Function() onCall;

  @override
  Future<BootstrapResult> bootstrap() async {
    onCall();
    return BootstrapResult(
      bootstrap: AppBootstrap(
        user: User(
          id: 'u_demo',
          name: 'Ana Torres',
          email: 'ana@neobank.com',
          segment: UserSegment.premium,
          createdAt: DateTime(2026, 1, 1),
        ),
        version: 'test',
        flags: const [],
        home: const [],
        offers: const [],
        theme: const AppThemeConfig(),
      ),
    );
  }
}

void main() {
  test('sin sesión no llama al API de bootstrap', () async {
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_GuestAuth.new),
        configRepositoryProvider.overrideWith(
          (ref) => _CountingConfigRepository(() => calls++),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.future);
    final result = await container.read(bootstrapProvider.future);
    container.read(themeConfigProvider);

    expect(calls, 0);
    expect(result.bootstrap.version, 'guest');
  });

  test('con sesión pide el bootstrap al repositorio', () async {
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_SessionAuth.new),
        configRepositoryProvider.overrideWith(
          (ref) => _CountingConfigRepository(() => calls++),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.future);
    final result = await container.read(bootstrapProvider.future);

    expect(calls, 1);
    expect(result.bootstrap.version, 'test');
  });
}
