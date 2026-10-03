import 'package:neobank_core/neobank_core.dart';
import 'package:test/test.dart';

void main() {
  group('Result', () {
    test('fold sobre Ok', () {
      const Result<int> result = Ok(2);
      final value = result.fold((v) => v * 10, (e) => -1);
      expect(value, 20);
      expect(result.valueOrNull, 2);
    });

    test('fold sobre Err', () {
      const Result<int> result = Err('boom');
      final value = result.fold((v) => v * 10, (e) => -1);
      expect(value, -1);
      expect(result.errorOrNull, 'boom');
      expect(result.isErr, isTrue);
    });
  });

  group('json utils', () {
    test('parsea fechas a hora local', () {
      final json = {'createdAt': '2026-01-01T00:00:00.000Z'};
      final date = jsonDate(json, 'createdAt');
      expect(date.isUtc, isFalse);
    });

    test('lista tolera entradas no-mapa', () {
      final json = {
        'items': [
          {'id': 'a'},
          42,
          {'id': 'b'},
        ],
      };
      expect(jsonList(json, 'items').length, 2);
    });

    test('campo requerido faltante lanza excepción', () {
      expect(() => jsonString({}, 'missing'), throwsA(isA<JsonFieldException>()));
    });
  });
}
