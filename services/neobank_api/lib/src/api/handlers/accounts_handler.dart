import 'package:neobank_core/neobank_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../../app.dart';
import '../../domain/errors.dart';
import '../http_helpers.dart';
import '../middleware.dart';

/// Gestión de cuentas, saldos, movimientos y transferencias.
class AccountsHandler {
  const AccountsHandler(this.app);

  final AppContainer app;

  Future<Response> list(Request request) async {
    final user = currentUser(request);
    final accounts = app.store.accountsForUser(user.id);
    final currency = accounts.isEmpty ? 'USD' : accounts.first.currency;
    final totalMinor = accounts
        .where((account) => account.currency == currency)
        .where((account) => account.type != AccountType.credit)
        .fold<int>(0, (sum, account) => sum + account.balance.minorUnits);
    final summary = AccountsSummary(
      accounts: accounts,
      totalBalance: Money(totalMinor, currency),
      currency: currency,
    );
    return jsonResponse(summary.toJson());
  }

  Future<Response> detail(Request request) async {
    final user = currentUser(request);
    final account = _requireOwnedAccount(user, request.params['id']);
    return jsonResponse(account.toJson());
  }

  Future<Response> transactions(Request request) async {
    final user = currentUser(request);
    final account = _requireOwnedAccount(user, request.params['id']);
    final cursor = request.url.queryParameters['cursor'];
    final limit =
        int.tryParse(request.url.queryParameters['limit'] ?? '') ?? 20;
    final page = app.store.transactionsForAccount(
      account.id,
      cursor: cursor,
      limit: limit.clamp(1, 100),
    );
    return jsonResponse(page.toJson());
  }

  Future<Response> transfer(Request request) async {
    final user = currentUser(request);
    final body = await readJson(request);
    final fromId = body['fromAccountId'] as String? ?? '';
    final amountMinor = (body['amountMinor'] as num?)?.toInt() ?? 0;
    final description =
        (body['description'] as String?)?.trim() ?? 'Transferencia';
    final toAccountId = body['toAccountId'] as String?;
    final beneficiary = (body['beneficiaryName'] as String?)?.trim();

    if (amountMinor <= 0) {
      throw ApiException.badRequest('El monto debe ser mayor a cero');
    }
    final from = _requireOwnedAccount(user, fromId);
    if (from.available.minorUnits < amountMinor) {
      throw ApiException.conflict('Fondos insuficientes');
    }

    final isInternal = toAccountId != null && toAccountId.isNotEmpty;
    final debit = app.store.applyTransaction(
      accountId: from.id,
      type: TransactionType.debit,
      category: isInternal ? 'transfer' : 'payment',
      description: isInternal ? description : '$description · ${beneficiary ?? 'beneficiario'}',
      amountMinor: amountMinor,
      currency: from.currency,
      merchant: isInternal ? null : beneficiary,
    );

    if (isInternal) {
      final to = _requireOwnedAccount(user, toAccountId);
      app.store.applyTransaction(
        accountId: to.id,
        type: TransactionType.credit,
        category: 'transfer',
        description: 'Transferencia de ${from.alias}',
        amountMinor: amountMinor,
        currency: to.currency,
        merchant: from.alias,
      );
    }

    await app.notifications.onTransaction(
      userId: user.id,
      transaction: debit,
      accountAlias: from.alias,
    );
    return jsonResponse(debit.toJson(), status: 201);
  }

  BankAccount _requireOwnedAccount(User user, String? id) {
    if (id == null || id.isEmpty) {
      throw ApiException.badRequest('Falta el identificador de cuenta');
    }
    final account = app.store.accountById(id);
    if (account == null || account.userId != user.id) {
      throw ApiException.notFound('Cuenta no encontrada');
    }
    return account;
  }
}

/// Registro de dispositivos para notificaciones push.
class DevicesHandler {
  const DevicesHandler(this.app);

  final AppContainer app;

  Future<Response> register(Request request) async {
    final user = currentUser(request);
    final body = await readJson(request);
    final token = (body['token'] as String?)?.trim() ?? '';
    final platform = (body['platform'] as String?)?.trim() ?? 'unknown';
    if (token.isEmpty) {
      throw ApiException.badRequest('El token del dispositivo es obligatorio');
    }
    app.store.upsertDeviceToken(
      id: const Uuid().v4(),
      userId: user.id,
      token: token,
      platform: platform,
    );
    return noContent();
  }
}
