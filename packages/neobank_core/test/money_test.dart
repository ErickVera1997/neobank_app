import 'package:neobank_core/neobank_core.dart';
import 'package:test/test.dart';

void main() {
  group('Money', () {
    test('suma y resta en unidades menores sin perder precisión', () {
      const a = Money(1050, 'USD');
      const b = Money(250, 'USD');

      expect((a + b).minorUnits, 1300);
      expect((a - b).minorUnits, 800);
      expect((-a).minorUnits, -1050);
    });

    test('fromAmount redondea a centavos', () {
      expect(Money.fromAmount(10.005, 'USD').minorUnits, 1001);
      expect(Money.fromAmount(10.004, 'USD').minorUnits, 1000);
    });

    test('no permite operar monedas distintas', () {
      expect(
        () => const Money(100, 'USD') + const Money(100, 'EUR'),
        throwsArgumentError,
      );
    });

    test('round-trip JSON', () {
      const original = Money(123456, 'COP');
      expect(Money.fromJson(original.toJson()), original);
    });

    test('formatea con símbolo de la divisa', () {
      expect(const Money(123456, 'USD').format(locale: 'en_US'), r'$1,234.56');
    });
  });
}
