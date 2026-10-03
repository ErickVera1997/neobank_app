import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:neobank_mobile/src/app.dart';
import 'package:neobank_mobile/src/core/config/app_config.dart';
import 'package:neobank_mobile/src/core/providers.dart';
import 'package:neobank_mobile/src/core/storage/cache_store.dart';
import 'package:neobank_mobile/src/core/storage/token_store.dart';

/// Backend simulado a nivel HTTP: el resto del stack (repositorios,
/// controladores, Riverpod y UI) es el código real de la app.
class _FakeBackend {
  ResponseBody handle(RequestOptions options) {
    final path = options.uri.path;
    if (path.contains('/auth/login')) return _session();
    if (path.contains('/config/bootstrap')) return _bootstrap();
    if (path.endsWith('/insights')) return _insights();
    if (path.endsWith('/assistant')) return _assistant();
    if (path.contains('/accounts/') && path.endsWith('/transactions')) {
      return _transactions();
    }
    if (path.contains('/accounts/')) return _account();
    if (path.endsWith('/accounts')) return _accounts();
    if (path.contains('/notifications')) return _notifications();
    if (path.contains('/fx/rates')) return _rates();
    if (path.contains('/devices')) {
      return ResponseBody.fromString('', 204);
    }
    return ResponseBody.fromString(
      jsonEncode({'code': 'not_found', 'message': path}),
      404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  ResponseBody _json(Object data) => ResponseBody.fromString(
        jsonEncode(data),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  ResponseBody _session() => _json({
        'user': {
          'id': 'u1',
          'name': 'Ana Torres',
          'email': 'ana@neobank.com',
          'segment': 'premium',
          'createdAt': '2026-01-01T00:00:00.000Z',
        },
        'tokens': {
          'accessToken': 'access',
          'refreshToken': 'refresh',
          'expiresIn': 900,
        },
      });

  ResponseBody _bootstrap() => _json({
        'user': {
          'id': 'u1',
          'name': 'Ana Torres',
          'email': 'ana@neobank.com',
          'segment': 'premium',
          'createdAt': '2026-01-01T00:00:00.000Z',
        },
        'version': 'bootstrap-1',
        'experimentBucket': 'B',
        'theme': {'brandName': 'Neobank', 'seedColorHex': '#0F62FE'},
        'flags': [
          {'key': 'fx_widget', 'enabled': true},
          {'key': 'offers_carousel', 'enabled': true},
          {'key': 'insights', 'enabled': true},
        ],
        'home': [
          {
            'id': 'hero',
            'type': 'heroBalance',
            'priority': 10,
            'title': 'Tu dinero',
          },
          {
            'id': 'actions',
            'type': 'quickActions',
            'priority': 20,
            'config': {
              'items': ['transfer', 'assistant', 'insights', 'fx'],
            },
          },
          {
            'id': 'assistant',
            'type': 'assistant',
            'priority': 25,
            'title': 'Copiloto financiero',
            'subtitle': 'Pregúntame por tus finanzas',
            'config': {
              'examples': ['¿Cuál es mi saldo?', '¿Cuánto gasté este mes?'],
            },
          },
          {
            'id': 'fx',
            'type': 'fxWidget',
            'priority': 30,
            'title': 'Conversión de divisas',
            'config': {'defaultFrom': 'USD', 'defaultTo': 'EUR'},
          },
          {
            'id': 'insights',
            'type': 'insights',
            'priority': 40,
            'title': 'Insights del mes',
          },
          {
            'id': 'offers',
            'type': 'offersCarousel',
            'priority': 50,
            'title': 'Para ti',
          },
        ],
        'offers': [
          {
            'id': 'cashback',
            'title': '3% de cashback',
            'description': 'En restaurantes este mes',
            'priority': 10,
            'ctaLabel': 'Ver más',
          },
        ],
      });

  ResponseBody _accounts() => _json({
        'accounts': [
          {
            'id': 'acc_checking',
            'userId': 'u1',
            'type': 'checking',
            'alias': 'Cuenta principal',
            'numberMasked': '**** 1190',
            'currency': 'USD',
            'balance': {'minorUnits': 1600000, 'currency': 'USD'},
            'available': {'minorUnits': 1600000, 'currency': 'USD'},
            'status': 'active',
            'createdAt': '2026-01-01T00:00:00.000Z',
          },
        ],
        'totalBalance': {'minorUnits': 1600000, 'currency': 'USD'},
        'currency': 'USD',
      });

  ResponseBody _account() => _json({
        'id': 'acc_checking',
        'userId': 'u1',
        'type': 'checking',
        'alias': 'Cuenta principal',
        'numberMasked': '**** 1190',
        'currency': 'USD',
        'balance': {'minorUnits': 1600000, 'currency': 'USD'},
        'available': {'minorUnits': 1600000, 'currency': 'USD'},
        'status': 'active',
        'createdAt': '2026-01-01T00:00:00.000Z',
      });

  ResponseBody _transactions() => _json({
        'items': [
          {
            'id': 't1',
            'accountId': 'acc_checking',
            'type': 'debit',
            'category': 'groceries',
            'description': 'Supermercado',
            'amount': {'minorUnits': -65120, 'currency': 'USD'},
            'balanceAfter': {'minorUnits': 1600000, 'currency': 'USD'},
            'status': 'posted',
            'createdAt': '2026-10-01T12:00:00.000Z',
            'merchant': 'Supermaxi',
          },
        ],
        'nextCursor': null,
      });

  ResponseBody _notifications() => _json({
        'items': [
          {
            'id': 'n1',
            'title': 'Recibiste un abono',
            'body': '+USD 50.00',
            'type': 'transaction',
            'read': false,
            'createdAt': '2026-10-01T12:00:00.000Z',
            'data': {},
          },
        ],
        'unreadCount': 1,
      });

  ResponseBody _rates() => _json({
        'base': 'USD',
        'rates': {'EUR': 0.9, 'GBP': 0.8},
        'source': 'frankfurter',
        'fetchedAt': '2026-10-01T12:00:00.000Z',
        'stale': false,
      });

  ResponseBody _insights() => _json({
        'periodStart': '2026-10-01T00:00:00.000Z',
        'periodEnd': '2026-11-01T00:00:00.000Z',
        'income': {'minorUnits': 3200000, 'currency': 'USD'},
        'expenses': {'minorUnits': 831200, 'currency': 'USD'},
        'net': {'minorUnits': 2368800, 'currency': 'USD'},
        'currency': 'USD',
        'byCategory': [
          {
            'category': 'groceries',
            'amount': {'minorUnits': 651200, 'currency': 'USD'},
            'share': 0.78,
            'transactions': 2,
          },
        ],
        'topMerchants': [
          {
            'merchant': 'Supermaxi',
            'amount': {'minorUnits': 651200, 'currency': 'USD'},
          },
        ],
        'savingsRate': 0.74,
        'changeVsPrevious': -0.12,
        'transactionCount': 12,
        'messages': [
          {
            'id': 'top_category',
            'title': 'Tu mayor gasto: supermercado',
            'body': r'$6,512.00 este mes (78% del total).',
            'tone': 'neutral',
            'action': '¿Cuánto gasté en groceries?',
          },
        ],
        'generatedAt': '2026-10-03T12:00:00.000Z',
      });

  ResponseBody _assistant() => _json({
        'reply': r'Tu saldo total es $16,000.00 en 1 cuentas.',
        'intent': 'balance',
        'suggestions': ['¿Cuánto gasté este mes?'],
        'card': {
          'type': 'balance',
          'title': 'Saldo consolidado',
          'subtitle': '1 cuentas',
          'amount': {'minorUnits': 1600000, 'currency': 'USD'},
        },
      });
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._backend);

  final _FakeBackend _backend;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      _backend.handle(options);

  @override
  void close({bool force = false}) {}
}

Dio _fakeDio(_FakeBackend backend) {
  final dio = Dio(BaseOptions(baseUrl: 'http://fake.local'));
  dio.httpClientAdapter = _FakeAdapter(backend);
  return dio;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Con `--dart-define=REAL_BACKEND=true` el E2E usa el backend real
  /// (Dio + red del dispositivo) en lugar del adaptador HTTP falso.
  const useRealBackend = bool.fromEnvironment('REAL_BACKEND');

  testWidgets('E2E: login, home personalizado y movimientos de una cuenta',
      (tester) async {
    final backend = _FakeBackend();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          cacheStoreProvider.overrideWithValue(InMemoryCacheStore()),
          deviceOnlineProvider.overrideWith((ref) => Stream.value(true)),
          if (!useRealBackend) ...[
            appConfigProvider.overrideWithValue(
              const AppConfig(
                apiBaseUrl: 'http://fake.local',
                requestTimeout: Duration(seconds: 5),
                simulatorEnabled: false,
              ),
            ),
            dioProvider.overrideWithValue(_fakeDio(backend)),
            refreshDioProvider.overrideWithValue(_fakeDio(backend)),
          ],
        ],
        child: const NeobankApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 1) Pantalla de login tras restaurar la sesión (sin tokens).
    expect(find.text('Bienvenida a Neobank'), findsOneWidget);

    // 2) Login con el usuario demo.
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    // 3) Home personalizado por el backend (hero + módulos).
    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text('Tu dinero'), findsOneWidget);
    expect(find.text('Conversión de divisas'), findsOneWidget);

    // 4) Copiloto financiero: responde con datos reales del usuario.
    final prompt = find.text('¿Cuál es mi saldo?').first;
    await tester.ensureVisible(prompt);
    await tester.tap(prompt);
    await tester.pumpAndSettle();
    expect(find.textContaining('Tu saldo total'), findsOneWidget);
    expect(find.text('Saldo consolidado'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 5) Navegar a cuentas y abrir el detalle.
    await tester.tap(find.text('Cuentas'));
    await tester.pumpAndSettle();
    expect(find.text('Mis cuentas'), findsOneWidget);
    expect(find.text('Cuenta principal'), findsOneWidget);

    await tester.tap(find.text('Cuenta principal'));
    await tester.pumpAndSettle();
    expect(find.text('Movimientos'), findsOneWidget);
    expect(find.text('Supermercado'), findsOneWidget);
  });
}