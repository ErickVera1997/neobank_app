import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neobank_core/neobank_core.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';

/// Cliente de la micro-app de divisas (contra el backend, que a su vez
/// integra un proveedor externo real).
class FxRepository {
  FxRepository(this._client);

  final ApiClient _client;

  Future<FxRates> rates(String base) async {
    final uri = Uri(
      path: ApiPaths.fxRates,
      queryParameters: {'base': base.toUpperCase()},
    );
    final result = await _client.getJson(
      uri.toString(),
      cacheKey: 'fx.$base',
    );
    return FxRates.fromJson(result.data);
  }

  Future<FxConversion> convert({
    required String from,
    required String to,
    required int amountMinor,
  }) async {
    final data = await _client.postJson(
      ApiPaths.fxConvert,
      body: {'from': from, 'to': to, 'amountMinor': amountMinor},
    );
    return FxConversion.fromJson(data);
  }
}

final fxRepositoryProvider = Provider<FxRepository>(
  (ref) => FxRepository(ref.watch(apiClientProvider)),
);

/// Tasas de cambio para una divisa base.
final fxRatesProvider = FutureProvider.autoDispose.family<FxRates, String>(
  (ref, base) => ref.read(fxRepositoryProvider).rates(base),
);
