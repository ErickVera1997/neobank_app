import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neobank_core/neobank_core.dart';
import 'package:neobank_mobile/src/features/auth/application/auth_controller.dart';
import 'package:neobank_mobile/src/features/notifications/application/notifications_controller.dart';
import 'package:neobank_mobile/src/features/notifications/data/notifications_repository.dart';
import 'package:neobank_mobile/src/features/notifications/services/push_service.dart';

class _SessionAuth extends AuthController {
  @override
  Future<User?> build() async => User(
        id: 'u1',
        name: 'Ana Torres',
        email: 'ana@neobank.com',
        segment: UserSegment.premium,
        createdAt: DateTime(2026, 1, 1),
      );
}

/// Repositorio con guion: devuelve una página distinta en cada consulta.
class _ScriptedRepository implements NotificationsRepository {
  _ScriptedRepository(this._pages);

  final List<NotificationsResult> _pages;
  int _calls = 0;

  @override
  Future<NotificationsResult> list() async {
    final index = _calls < _pages.length ? _calls : _pages.length - 1;
    _calls++;
    return _pages[index];
  }

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> registerDevice({
    required String token,
    required String platform,
  }) async {}
}

/// Servicio de push falso que registra lo que se mostraría en el sistema.
class _RecordingPushService implements PushService {
  final List<AppNotification> shown = [];

  @override
  bool get permissionGranted => true;

  @override
  Future<String?> initialize() async => 'token';

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<void> registerDevice() async {}

  @override
  Future<void> show(AppNotification notification) async =>
      shown.add(notification);
}

AppNotification _notification(String id) => AppNotification(
      id: id,
      title: 'Título $id',
      body: 'Cuerpo $id',
      type: AppNotificationType.transaction,
      createdAt: DateTime(2026, 1, 1),
    );

NotificationsResult _result(List<AppNotification> items) => NotificationsResult(
      items: items,
      unreadCount: items.where((item) => !item.read).length,
    );

void main() {
  test('no notifica la carga inicial y sí las nuevas en cada sondeo', () async {
    final repository = _ScriptedRepository([
      _result([_notification('n1')]),
      _result([_notification('n1'), _notification('n2')]),
      _result([_notification('n1'), _notification('n2'), _notification('n3')]),
    ]);
    final push = _RecordingPushService();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_SessionAuth.new),
        notificationsRepositoryProvider.overrideWithValue(repository),
        pushServiceProvider.overrideWithValue(push),
      ],
    );
    addTearDown(container.dispose);

    // Sesión resuelta antes de cargar notificaciones.
    await container.read(authControllerProvider.future);
    await container.read(notificationsProvider.future);

    // Carga inicial: lo existente no genera avisos.
    expect(push.shown, isEmpty);

    // Primer sondeo: aparece n2.
    await container.read(notificationsProvider.notifier).poll();
    expect(push.shown.map((item) => item.id), ['n2']);

    // Segundo sondeo: aparece n3 (n1 y n2 ya fueron vistos).
    await container.read(notificationsProvider.notifier).poll();
    expect(push.shown.map((item) => item.id), ['n2', 'n3']);

    // El contador refleja la última página.
    expect(container.read(unreadNotificationsProvider), 3);
  });

  test('marcar como leída actualiza el contador sin volver a notificar',
      () async {
    final repository = _ScriptedRepository([
      _result([_notification('n1'), _notification('n2')]),
    ]);
    final push = _RecordingPushService();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_SessionAuth.new),
        notificationsRepositoryProvider.overrideWithValue(repository),
        pushServiceProvider.overrideWithValue(push),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.future);
    await container.read(notificationsProvider.future);
    expect(container.read(unreadNotificationsProvider), 2);

    await container.read(notificationsProvider.notifier).markRead('n1');
    expect(container.read(unreadNotificationsProvider), 1);
    expect(push.shown, isEmpty);
  });
}