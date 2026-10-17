import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neobank_core/neobank_core.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../accounts/application/accounts_controller.dart';
import '../../notifications/application/notifications_controller.dart';

/// Ejecuta transferencias internas y a terceros.
class TransfersRepository {
  TransfersRepository(this._client);

  final ApiClient _client;

  Future<BankTransaction> transfer({
    required String fromAccountId,
    required int amountMinor,
    required String description,
    String? toAccountId,
    String? beneficiaryName,
  }) async {
    final data = await _client.postJson(
      ApiPaths.transfers,
      body: {
        'fromAccountId': fromAccountId,
        'amountMinor': amountMinor,
        'description': description,
        if (toAccountId != null) 'toAccountId': toAccountId,
        if (beneficiaryName != null) 'beneficiaryName': beneficiaryName,
      },
    );
    return BankTransaction.fromJson(data);
  }
}

final transfersRepositoryProvider = Provider<TransfersRepository>(
  (ref) => TransfersRepository(ref.watch(apiClientProvider)),
);

/// Notificador del formulario de transferencia.
class TransferController extends Notifier<AsyncValue<BankTransaction?>> {
  @override
  AsyncValue<BankTransaction?> build() => const AsyncData(null);

  Future<bool> submit({
    required String fromAccountId,
    required int amountMinor,
    required String description,
    String? toAccountId,
    String? beneficiaryName,
  }) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      final transaction = await ref
          .read(transfersRepositoryProvider)
          .transfer(
            fromAccountId: fromAccountId,
            amountMinor: amountMinor,
            description: description,
            toAccountId: toAccountId,
            beneficiaryName: beneficiaryName,
          );
      success = true;
      return transaction;
    });
    if (success) {
      ref.invalidate(accountsSummaryProvider);
      ref.invalidate(transactionsProvider);
      // Sondear en el MISMO controlador (no invalidar) para que la nueva
      // notificación dispare el aviso del sistema de inmediato.
      unawaited(ref.read(notificationsProvider.notifier).poll());
    }
    return success;
  }

  void reset() => state = const AsyncData(null);
}

final transferControllerProvider =
    NotifierProvider<TransferController, AsyncValue<BankTransaction?>>(
  TransferController.new,
);
