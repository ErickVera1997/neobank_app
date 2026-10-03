import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neobank_api/neobank_api.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

http.Client _fxClient() => MockClient((request) async {
      return http.Response(
        jsonEncode({
          'base': 'USD',
          'rates': {'EUR': 0.9, 'GBP': 0.8, 'COP': 4000},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

class _Harness {
  _Harness()
      : config = const AppConfig(
          port: 0,
          databasePath: ':memory:',
          jwtSecret: 'test-secret',
          accessTokenTtl: Duration(minutes: 10),
          refreshTokenTtl: Duration(days: 1),
          otpTtl: Duration(minutes: 5),
          fxBaseUrl: 'https://fx.test',
          environment: 'development',
        ) {
    app = AppContainer.create(config, httpClient: _fxClient());
    handler = buildHandler(app);
  }

  final AppConfig config;
  late final AppContainer app;
  late final Handler handler;
  String? _token;

  Future<Response> call(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) {
    return Future.value(
      handler(
        Request(
          method,
          Uri.parse('http://localhost$path'),
          headers: {
            'content-type': 'application/json',
            if (authenticated && _token != null)
              'authorization': 'Bearer $_token',
          },
          body: body == null ? null : jsonEncode(body),
        ),
      ),
    );
  }

  Future<void> login() async {
    final response = await call(
      'POST',
      '/auth/login',
      authenticated: false,
      body: {'email': SeedData.demoEmail, 'password': SeedData.demoPassword},
    );
    final json = jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    _token = (json['tokens'] as Map<String, dynamic>)['accessToken'] as String;
  }

  Future<Map<String, dynamic>> json(Response response) async =>
      jsonDecode(await response.readAsString()) as Map<String, dynamic>;

  void dispose() => app.dispose();
}

void main() {
  late _Harness harness;

  setUp(() async {
    harness = _Harness();
    await harness.login();
  });
  tearDown(() => harness.dispose());

  group('GET /insights', () {
    test('genera analítica real a partir de los movimientos', () async {
      final response = await harness.call('GET', '/insights');
      final json = await harness.json(response);

      expect(response.statusCode, 200);
      expect((json['expenses'] as Map)['minorUnits'], greaterThan(0));
      expect(json['byCategory'], isNotEmpty);
      expect(json['messages'], isNotEmpty);
      expect(json['currency'], 'USD');
      expect((json['savingsRate'] as num), isA<num>());
    });
  });

  group('POST /assistant', () {
    Future<Map<String, dynamic>> ask(String message) async {
      final response = await harness.call(
        'POST',
        '/assistant',
        body: {'message': message},
      );
      expect(response.statusCode, 200);
      return harness.json(response);
    }

    test('responde el saldo consolidado', () async {
      final json = await ask('¿Cuál es mi saldo?');
      expect(json['intent'], 'balance');
      expect(json['card']['type'], 'balance');
      expect((json['card']['amount'] as Map)['minorUnits'], greaterThan(0));
    });

    test('calcula el gasto del mes', () async {
      final json = await ask('¿Cuánto gasté este mes?');
      expect(json['intent'], 'spending_total');
      expect(
        (json['card']['amount'] as Map)['minorUnits'],
        greaterThan(0),
      );
    });

    test('detalla el gasto por categoría', () async {
      final json = await ask('¿Cuánto gasté en supermercado?');
      expect(json['intent'], 'spending_category');
      expect((json['reply'] as String).toLowerCase(), contains('supermercado'));
    });

    test('convierte divisas con el proveedor real', () async {
      final json = await ask('¿Cuánto es 100 USD en EUR?');
      expect(json['intent'], 'fx_conversion');
      expect(json['card']['type'], 'conversion');
      expect((json['card']['conversion'] as Map)['result']['minorUnits'], 9000);
    });

    test('lista los últimos movimientos', () async {
      final json = await ask('Muéstrame mis últimos movimientos');
      expect(json['intent'], 'movements');
      expect(
        (json['card']['transactions'] as List<dynamic>).length,
        lessThanOrEqualTo(5),
      );
    });

    test('responde con ayuda ante una pregunta desconocida', () async {
      final json = await ask('¿Puedes recomendarme una película?');
      expect(json['intent'], 'help');
      expect(json['suggestions'], isNotEmpty);
    });
  });

  group('Bootstrap personalizado', () {
    test('incluye el copiloto y ofertas generadas por comportamiento',
        () async {
      final response = await harness.call('GET', '/config/bootstrap');
      final json = await harness.json(response);

      final moduleTypes = (json['home'] as List<dynamic>)
          .map((module) => (module as Map<String, dynamic>)['type'])
          .toList();
      expect(moduleTypes, contains('assistant'));

      final offerIds = (json['offers'] as List<dynamic>)
          .map((offer) => (offer as Map<String, dynamic>)['id'] as String)
          .toList();
      expect(offerIds.any((id) => id.startsWith('dyn_')), isTrue);
    });
  });
}