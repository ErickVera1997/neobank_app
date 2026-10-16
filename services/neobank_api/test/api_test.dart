import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neobank_api/neobank_api.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Cliente FX simulado: devuelve tasas reales de prueba sin salir a Internet.
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

  Future<Response> call(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) {
    return Future.value(
      handler(
        Request(
          method,
          Uri.parse('http://localhost$path'),
          headers: {
            'content-type': 'application/json',
            if (token != null) 'authorization': 'Bearer $token',
          },
          body: body == null ? null : jsonEncode(body),
        ),
      ),
    );
  }

  Future<Response> login([String password = SeedData.demoPassword]) => call(
        'POST',
        '/auth/login',
        body: {'email': SeedData.demoEmail, 'password': password},
      );

  Future<Map<String, dynamic>> loginJson() async {
    final response = await login();
    return jsonDecode(await response.readAsString()) as Map<String, dynamic>;
  }

  void dispose() => app.dispose();
}

Future<Map<String, dynamic>> _json(Response response) async =>
    jsonDecode(await response.readAsString()) as Map<String, dynamic>;

void main() {
  late _Harness harness;

  setUp(() => harness = _Harness());
  tearDown(() => harness.dispose());

  test('GET /health responde ok', () async {
    final response = await harness.call('GET', '/health');
    expect(response.statusCode, 200);
    expect((await _json(response))['status'], 'ok');
  });

  test('login con credenciales válidas devuelve usuario y tokens', () async {
    final json = await harness.loginJson();
    expect(json['user']['email'], SeedData.demoEmail);
    expect(json['tokens']['accessToken'], isNotEmpty);
    expect(json['tokens']['refreshToken'], isNotEmpty);
  });

  test('login con contraseña incorrecta devuelve 401', () async {
    final response = await harness.login('incorrecta');
    expect(response.statusCode, 401);
  });

  test('las rutas protegidas exigen token', () async {
    final response = await harness.call('GET', '/accounts');
    expect(response.statusCode, 401);
  });

  test('logout exige token y revoca el refresh token', () async {
    final session = await harness.loginJson();
    final token = session['tokens']['accessToken'] as String;
    final refreshToken = session['tokens']['refreshToken'] as String;

    final logout = await harness.call(
      'POST',
      '/auth/logout',
      token: token,
      body: {'refreshToken': refreshToken},
    );
    expect(logout.statusCode, 204);

    final renewed = await harness.call(
      'POST',
      '/auth/refresh',
      body: {'refreshToken': refreshToken},
    );
    expect(renewed.statusCode, 401);
  });

  test('el usuario demo tiene cuentas y saldo consolidado', () async {
    final session = await harness.loginJson();
    final token = session['tokens']['accessToken'] as String;

    final response = await harness.call('GET', '/accounts', token: token);
    final json = await _json(response);

    expect(response.statusCode, 200);
    final accounts = json['accounts'] as List<dynamic>;
    expect(accounts, isNotEmpty);
    expect(json['totalBalance']['minorUnits'], greaterThan(0));
  });

  test('los movimientos se paginan por cursor', () async {
    final token = (await harness.loginJson())['tokens']['accessToken'] as String;
    final first = await _json(
      await harness.call(
        'GET',
        '/accounts/acc_checking/transactions?limit=5',
        token: token,
      ),
    );
    final items = first['items'] as List<dynamic>;
    expect(items.length, 5);
    expect(first['nextCursor'], isNotNull);

    final second = await _json(
      await harness.call(
        'GET',
        '/accounts/acc_checking/transactions'
        '?limit=5&cursor=${first['nextCursor']}',
        token: token,
      ),
    );
    expect((second['items'] as List<dynamic>).length, 5);
    expect(
      (second['items'] as List<dynamic>).first['id'],
      isNot(equals(items.first['id'])),
    );
  });

  test('transferencia interna debita, acredita y notifica', () async {
    final token = (await harness.loginJson())['tokens']['accessToken'] as String;

    final response = await harness.call(
      'POST',
      '/transfers',
      token: token,
      body: {
        'fromAccountId': 'acc_checking',
        'toAccountId': 'acc_savings',
        'amountMinor': 10000,
        'description': 'Ahorro semanal',
      },
    );
    expect(response.statusCode, 201);

    final notifications = await _json(
      await harness.call('GET', '/notifications', token: token),
    );
    expect(notifications['items'], isNotEmpty);
  });

  test('transferencia sin fondos devuelve 409', () async {
    final token = (await harness.loginJson())['tokens']['accessToken'] as String;
    final response = await harness.call(
      'POST',
      '/transfers',
      token: token,
      body: {
        'fromAccountId': 'acc_savings',
        'amountMinor': 999999999,
        'description': 'Imposible',
      },
    );
    expect(response.statusCode, 409);
  });

  test('FX convierte usando el proveedor externo', () async {
    final token = (await harness.loginJson())['tokens']['accessToken'] as String;
    final response = await harness.call(
      'POST',
      '/fx/convert',
      token: token,
      body: {'from': 'USD', 'to': 'EUR', 'amountMinor': 10000},
    );
    final json = await _json(response);
    expect(response.statusCode, 200);
    expect(json['result']['minorUnits'], 9000);
    expect(json['stale'], isFalse);
  });

  test('el bootstrap personaliza el home según el segmento', () async {
    final token = (await harness.loginJson())['tokens']['accessToken'] as String;
    final json = await _json(
      await harness.call('GET', '/config/bootstrap', token: token),
    );

    final modules = (json['home'] as List<dynamic>)
        .map((module) => (module as Map<String, dynamic>)['type'])
        .toList();
    expect(modules, contains('fxWidget'));
    expect(modules, contains('heroBalance'));
    // El usuario demo es premium: recibe el módulo de adelanto de salario.
    expect(modules, contains('promo'));
    expect(json['offers'], isNotEmpty);
  });

  test('registro crea cuenta base con bono de bienvenida', () async {
    final response = await harness.call(
      'POST',
      '/auth/register',
      body: {
        'name': 'Nuevo Cliente',
        'email': 'nuevo@neobank.com',
        'password': 'Password123',
        'segment': 'standard',
      },
    );
    expect(response.statusCode, 201);
    final session = await _json(response);
    final token = session['tokens']['accessToken'] as String;

    final accounts = await _json(
      await harness.call('GET', '/accounts', token: token),
    );
    final list = accounts['accounts'] as List<dynamic>;
    expect(list.length, 1);
    expect(list.first['balance']['minorUnits'], 5000);
  });
}
