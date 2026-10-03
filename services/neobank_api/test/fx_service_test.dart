import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neobank_api/neobank_api.dart';
import 'package:test/test.dart';

http.Client _okClient({void Function()? onCall}) => MockClient((request) async {
      onCall?.call();
      return http.Response(
        jsonEncode({
          'amount': 1,
          'base': 'USD',
          'rates': {'EUR': 0.9, 'GBP': 0.8, 'COP': 4000},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

http.Client _failingClient() =>
    MockClient((request) async => http.Response('boom', 500));

void main() {
  group('FxService', () {
    late AppDatabase database;
    late Store store;

    setUp(() {
      database = AppDatabase.inMemory();
      store = Store(database);
    });

    tearDown(() => database.close());

    test('consulta el proveedor y guarda caché', () async {
      var calls = 0;
      final service = FxService(
        store,
        'https://fx.test',
        client: _okClient(onCall: () => calls++),
      );

      final rates = await service.rates('USD');
      expect(rates.rateFor('EUR'), 0.9);
      expect(rates.stale, isFalse);
      expect(calls, 1);

      // Segunda llamada dentro del TTL: usa caché, no vuelve a la red.
      final cached = await service.rates('USD');
      expect(cached.stale, isFalse);
      expect(calls, 1);
    });

    test('devuelve datos stale cuando el proveedor falla', () async {
      final priming = FxService(store, 'https://fx.test', client: _okClient());
      await priming.rates('USD');

      final failing = FxService(
        store,
        'https://fx.test',
        client: _failingClient(),
        ttl: Duration.zero,
      );
      final stale = await failing.rates('USD');
      expect(stale.stale, isTrue);
      expect(stale.rateFor('EUR'), 0.9);
    });

    test('propaga 503 cuando no hay caché', () async {
      final failing = FxService(
        store,
        'https://fx.test',
        client: _failingClient(),
      );
      expect(
        () => failing.rates('USD'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 503),
        ),
      );
    });

    test('convierte montos aplicando la tasa', () async {
      final service = FxService(store, 'https://fx.test', client: _okClient());
      final conversion = await service.convert(
        from: 'USD',
        to: 'EUR',
        amountMinor: 10000,
      );
      expect(conversion.result.minorUnits, 9000);
      expect(conversion.rate, 0.9);
    });
  });
}
