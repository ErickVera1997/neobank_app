import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:neobank_core/neobank_core.dart';

import '../data/store.dart';
import '../domain/errors.dart';

/// Integración real con un proveedor de tipos de cambio (Frankfurter).
///
/// Estrategia de resiliencia:
/// 1. Si hay caché vigente (`ttl`) se responde sin salir a la red.
/// 2. Si no, se consulta el proveedor con `timeout` acotado.
/// 3. Si el proveedor falla pero hay caché previa, se responde **stale**
///    (`stale: true`) para que la UI lo indique y no se rompa la experiencia.
/// 4. Si no hay caché, se devuelve `503` con un código estable.
class FxService {
  FxService(
    this._store,
    this._baseUrl, {
    http.Client? client,
    this.ttl = const Duration(minutes: 15),
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client();

  final Store _store;
  final String _baseUrl;
  final http.Client _client;
  final Duration ttl;
  final Duration timeout;

  static const String sourceName = 'frankfurter';

  Future<FxRates> rates(String base) async {
    final normalizedBase = base.toUpperCase();
    final cached = _store.getFxCache(normalizedBase);
    if (cached != null && DateTime.now().difference(cached.fetchedAt) < ttl) {
      return FxRates(
        base: cached.base,
        rates: cached.rates,
        source: cached.source,
        fetchedAt: cached.fetchedAt,
      );
    }

    try {
      final uri = Uri.parse('$_baseUrl/latest').replace(
        queryParameters: {'from': normalizedBase},
      );
      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode != 200) {
        throw ApiException.unavailable(
          'Proveedor FX respondió ${response.statusCode}',
        );
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final rawRates = body['rates'] as Map? ?? const {};
      final ratesJson = rawRates.map(
        (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
      );
      final fetchedAt = DateTime.now();
      _store.saveFxCache(
        base: normalizedBase,
        rates: ratesJson,
        source: sourceName,
        fetchedAt: fetchedAt,
      );
      return FxRates(
        base: normalizedBase,
        rates: ratesJson,
        source: sourceName,
        fetchedAt: fetchedAt,
      );
    } catch (error) {
      if (cached != null) {
        return cached; // stale: true
      }
      throw ApiException.unavailable(
        'Proveedor FX no disponible y sin caché local ($error)',
      );
    }
  }

  Future<FxConversion> convert({
    required String from,
    required String to,
    required int amountMinor,
  }) async {
    final source = from.toUpperCase();
    final target = to.toUpperCase();
    if (source == target) {
      return FxConversion(
        from: source,
        to: target,
        source: 'identity',
        rate: 1,
        amount: Money(amountMinor, source),
        result: Money(amountMinor, target),
        fetchedAt: DateTime.now(),
      );
    }
    final fxRates = await rates(source);
    final rate = fxRates.rateFor(target);
    if (rate == null) {
      throw ApiException.badRequest('Divisa no soportada: $target');
    }
    return FxConversion(
      from: source,
      to: target,
      source: fxRates.source,
      rate: rate,
      amount: Money(amountMinor, source),
      result: Money((amountMinor * rate).round(), target),
      fetchedAt: fxRates.fetchedAt,
      stale: fxRates.stale,
    );
  }

  void dispose() => _client.close();
}
