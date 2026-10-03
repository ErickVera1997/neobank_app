import 'package:intl/intl.dart';

/// Valor monetario seguro expresado en unidades menores (centavos).
///
/// Evita errores de precisión de punto flotante al operar con dinero.
class Money implements Comparable<Money> {
  const Money(this.minorUnits, this.currency);

  /// Cantidad en la unidad menor (p. ej. centavos).
  final int minorUnits;

  /// Código ISO-4217 (p. ej. `USD`, `EUR`, `COP`).
  final String currency;

  factory Money.zero([String currency = 'USD']) => Money(0, currency);

  /// Construye desde una cantidad decimal, redondeando a la unidad menor.
  factory Money.fromAmount(num amount, String currency) =>
      Money((amount * 100).round(), currency);

  double get amount => minorUnits / 100;

  bool get isNegative => minorUnits < 0;
  bool get isZero => minorUnits == 0;

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(minorUnits + other.minorUnits, currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(minorUnits - other.minorUnits, currency);
  }

  Money operator -() => Money(-minorUnits, currency);

  Money abs() => Money(minorUnits.abs(), currency);

  void _assertSameCurrency(Money other) {
    if (other.currency != currency) {
      throw ArgumentError(
        'No se pueden operar monedas distintas: $currency vs ${other.currency}',
      );
    }
  }

  /// Formatea con símbolo y separadores según [locale].
  String format({String? locale, bool compact = false}) {
    final symbol = _symbols[currency] ?? '$currency ';
    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: symbol,
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  factory Money.fromJson(Map<String, dynamic> json) => Money(
        (json['minorUnits'] as num).toInt(),
        json['currency'] as String,
      );

  Map<String, dynamic> toJson() => {
        'minorUnits': minorUnits,
        'currency': currency,
      };

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => '${amount.toStringAsFixed(2)} $currency';

  static const Map<String, String> _symbols = {
    'USD': r'$',
    'EUR': '€',
    'COP': r'$',
    'MXN': r'$',
    'GBP': '£',
    'BRL': r'R$',
  };
}
