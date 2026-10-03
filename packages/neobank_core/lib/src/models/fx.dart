import '../json_utils.dart';
import '../money.dart';

/// Mapa de tipos de cambio respecto a una divisa base.
class FxRates {
  const FxRates({
    required this.base,
    required this.rates,
    required this.source,
    required this.fetchedAt,
    this.stale = false,
  });

  final String base;

  /// `quote -> tasa` (1 base = rate quote).
  final Map<String, double> rates;
  final String source;
  final DateTime fetchedAt;

  /// `true` si proviene de caché por indisponibilidad del proveedor.
  final bool stale;

  double? rateFor(String quote) => rates[quote.toUpperCase()];

  factory FxRates.fromJson(Map<String, dynamic> json) => FxRates(
        base: jsonString(json, 'base'),
        rates: jsonMap(json, 'rates').map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        ),
        source: jsonString(json, 'source', fallback: 'unknown'),
        fetchedAt: jsonDate(json, 'fetchedAt'),
        stale: jsonBool(json, 'stale'),
      );

  Map<String, dynamic> toJson() => {
        'base': base,
        'rates': rates,
        'source': source,
        'fetchedAt': fetchedAt.toUtc().toIso8601String(),
        'stale': stale,
      };
}

/// Resultado de una conversión de divisas.
class FxConversion {
  const FxConversion({
    required this.from,
    required this.to,
    required this.source,
    required this.rate,
    required this.amount,
    required this.result,
    required this.fetchedAt,
    this.stale = false,
  });

  final String from;
  final String to;
  final String source;
  final double rate;
  final Money amount;
  final Money result;
  final DateTime fetchedAt;
  final bool stale;

  factory FxConversion.fromJson(Map<String, dynamic> json) => FxConversion(
        from: jsonString(json, 'from'),
        to: jsonString(json, 'to'),
        source: jsonString(json, 'source', fallback: 'unknown'),
        rate: jsonDouble(json, 'rate'),
        amount: Money.fromJson(jsonMap(json, 'amount')),
        result: Money.fromJson(jsonMap(json, 'result')),
        fetchedAt: jsonDate(json, 'fetchedAt'),
        stale: jsonBool(json, 'stale'),
      );

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        'source': source,
        'rate': rate,
        'amount': amount.toJson(),
        'result': result.toJson(),
        'fetchedAt': fetchedAt.toUtc().toIso8601String(),
        'stale': stale,
      };
}
