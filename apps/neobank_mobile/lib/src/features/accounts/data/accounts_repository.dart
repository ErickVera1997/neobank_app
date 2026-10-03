import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neobank_core/neobank_core.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';

/// Resumen de cuentas con metadatos de caché.
class AccountsResult {
  const AccountsResult({
    required this.summary,
    this.fromCache = false,
    this.cachedAt,
  });

  final AccountsSummary summary;
  final bool fromCache;
  final DateTime? cachedAt;
}

/// Acceso a cuentas y movimientos.
class AccountsRepository {
  AccountsRepository(this._client);

  final ApiClient _client;

  Future<AccountsResult> summary() async {
    final result = await _client.getJson(
      ApiPaths.accounts,
      cacheKey: 'accounts',
    );
    return AccountsResult(
      summary: AccountsSummary.fromJson(result.data),
      fromCache: result.fromCache,
      cachedAt: result.cachedAt,
    );
  }

  Future<BankAccount> detail(String accountId) async {
    final result = await _client.getJson(
      ApiPaths.account(accountId),
      cacheKey: 'account.$accountId',
    );
    return BankAccount.fromJson(result.data);
  }

  Future<TransactionPage> transactions(
    String accountId, {
    String? cursor,
    int limit = 20,
  }) async {
    final uri = Uri(
      path: '/accounts/$accountId/transactions',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': '$limit',
      },
    );
    final result = await _client.getJson(
      uri.toString(),
      cacheKey: cursor == null ? 'transactions.$accountId' : null,
    );
    return TransactionPage.fromJson(result.data);
  }
}

final accountsRepositoryProvider = Provider<AccountsRepository>(
  (ref) => AccountsRepository(ref.watch(apiClientProvider)),
);
