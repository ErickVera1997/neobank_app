import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neobank_core/neobank_core.dart';

import '../../auth/application/auth_controller.dart';
import '../data/accounts_repository.dart';

/// Resumen consolidado de cuentas (con soporte offline).
final accountsSummaryProvider = FutureProvider<AccountsResult>((ref) async {
  ref.watch(currentUserIdProvider);
  return ref.read(accountsRepositoryProvider).summary();
});

/// Detalle de una cuenta concreta.
final accountDetailProvider =
    FutureProvider.autoDispose.family<BankAccount, String>((ref, accountId) {
  return ref.read(accountsRepositoryProvider).detail(accountId);
});

/// Primera página de movimientos de una cuenta.
final transactionsProvider = FutureProvider.autoDispose
    .family<TransactionPage, String>((ref, accountId) {
  return ref.read(accountsRepositoryProvider).transactions(accountId);
});
