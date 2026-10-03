import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neobank_core/neobank_core.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';

/// Analítica de gasto generada por el backend a partir de datos reales.
class InsightsRepository {
  InsightsRepository(this._client);

  final ApiClient _client;

  Future<SpendingInsights> monthly() async {
    final result = await _client.getJson(
      ApiPaths.insights,
      cacheKey: 'insights',
    );
    return SpendingInsights.fromJson(result.data);
  }
}

final insightsRepositoryProvider = Provider<InsightsRepository>(
  (ref) => InsightsRepository(ref.watch(apiClientProvider)),
);

final insightsProvider = FutureProvider<SpendingInsights>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.read(insightsRepositoryProvider).monthly();
});