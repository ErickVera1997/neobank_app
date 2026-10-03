import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:neobank_api/neobank_api.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Smoke test end-to-end del backend.
///
/// Levanta el servidor real (SQLite en memoria) en un puerto efímero y recorre
/// los flujos críticos por HTTP, incluida la llamada al proveedor FX externo.
///
/// Uso:
///   dart run tool/smoke.dart
///
/// La verificación de FX es tolerante a fallos de red: si el entorno no tiene
/// salida a Internet, se reporta como advertencia y el resto debe pasar.
Future<void> main(List<String> args) async {
  stdout.writeln('▶ Smoke test de Neobank API');
  final config = AppConfig.fromEnvironment(<String, String>{
    'DB_PATH': ':memory:',
    'JWT_SECRET': 'smoke-secret',
    'ENV': 'development',
    if (Platform.environment['FX_BASE_URL'] != null)
      'FX_BASE_URL': Platform.environment['FX_BASE_URL']!,
  });
  final app = AppContainer.create(config);
  final server = await shelf_io.serve(
    buildHandler(app),
    InternetAddress.loopbackIPv4,
    0,
  );
  final base = Uri.parse('http://${server.address.address}:${server.port}');
  final client = http.Client();
  var failures = 0;
  var warnings = 0;

  Future<Map<String, dynamic>> call(
    String method,
    String path, {
    Object? body,
    String? token,
    List<int> okStatuses = const [200],
  }) async {
    final request = http.Request(method, base.resolve(path));
    request.headers['content-type'] = 'application/json';
    if (token != null) request.headers['authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);
    final streamed = await client.send(request);
    final response = await http.Response.fromStream(streamed);
    if (!okStatuses.contains(response.statusCode)) {
      throw HttpException(
        '$method $path → ${response.statusCode}: ${response.body}',
      );
    }
    if (response.body.isEmpty) return <String, dynamic>{};
    return (jsonDecode(response.body) as Map).cast<String, dynamic>();
  }

  void check(String label, bool ok, [String? detail]) {
    final suffix = detail == null ? '' : ' · $detail';
    if (ok) {
      stdout.writeln('  ✅ $label$suffix');
    } else {
      failures++;
      stdout.writeln('  ❌ $label$suffix');
    }
  }

  try {
    final health = await call('GET', '/health');
    check('Salud del servicio', health['status'] == 'ok');

    final session = await call(
      'POST',
      '/auth/login',
      body: {
        'email': SeedData.demoEmail,
        'password': SeedData.demoPassword,
      },
    );
    final token =
        ((session['tokens'] as Map)['accessToken']).toString();
    check('Login del usuario demo', token.isNotEmpty);

    final accounts = await call('GET', '/accounts', token: token);
    final total = ((accounts['totalBalance'] as Map)['minorUnits'] as num).toInt();
    check(
      'Cuentas y saldo consolidado',
      total > 0,
      'total=${(total / 100).toStringAsFixed(2)} USD',
    );

    final transfer = await call(
      'POST',
      '/transfers',
      token: token,
      okStatuses: const [201],
      body: {
        'fromAccountId': 'acc_checking',
        'toAccountId': 'acc_savings',
        'amountMinor': 1000,
        'description': 'Smoke test',
      },
    );
    check('Transferencia interna', transfer['id'] != null);

    final notifications = await call('GET', '/notifications', token: token);
    check(
      'Centro de notificaciones',
      (notifications['items'] as List<dynamic>).isNotEmpty,
    );

    final insights = await call('GET', '/insights', token: token);
    check(
      'Insights dinámicos',
      ((insights['expenses'] as Map)['minorUnits'] as num) > 0,
      '${(insights['byCategory'] as List<dynamic>).length} categorías',
    );

    final assistant = await call(
      'POST',
      '/assistant',
      token: token,
      body: {'message': '¿Cuál es mi saldo?'},
    );
    check(
      'Copiloto financiero',
      assistant['intent'] == 'balance',
      assistant['reply'].toString().split('.').first,
    );

    final bootstrap = await call('GET', '/config/bootstrap', token: token);
    final modules = (bootstrap['home'] as List<dynamic>)
        .map((module) => (module as Map)['type'])
        .toList();
    final dynamicOffers = (bootstrap['offers'] as List<dynamic>).where(
      (offer) => (offer as Map)['id'].toString().startsWith('dyn_'),
    );
    check(
      'Home personalizado',
      modules.contains('heroBalance') && modules.contains('assistant'),
      '${modules.length} módulos',
    );
    check(
      'Ofertas por comportamiento',
      dynamicOffers.isNotEmpty,
      '${dynamicOffers.length} generadas',
    );

    try {
      final rates = await call('GET', '/fx/rates?base=USD', token: token);
      final eur = (rates['rates'] as Map)['EUR'];
      check(
        'Proveedor FX en vivo',
        eur != null,
        '1 USD = $eur EUR (${rates['source']})',
      );
    } on Exception catch (error) {
      warnings++;
      stdout.writeln('  ⚠️  FX no disponible en este entorno: $error');
      final degraded = await call(
        'GET',
        '/fx/rates?base=USD',
        token: token,
        okStatuses: const [200, 503],
      );
      check(
        'Degradación FX controlada',
        true,
        degraded['stale'] == true ? 'respondió con caché' : 'sin caché (503)',
      );
    }
  } on Exception catch (error) {
    failures++;
    stdout.writeln('  ❌ Error inesperado: $error');
  } finally {
    client.close();
    await server.close(force: true);
    app.dispose();
  }

  stdout.writeln('');
  if (failures == 0) {
    final suffix = warnings > 0 ? ' ($warnings advertencia(s))' : '';
    stdout.writeln('✅ Smoke test OK$suffix');
    exit(0);
  }
  stdout.writeln('❌ Smoke test con $failures fallo(s)');
  exit(1);
}