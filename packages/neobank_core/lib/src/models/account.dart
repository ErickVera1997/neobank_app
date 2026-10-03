import '../json_utils.dart';
import '../money.dart';

enum AccountType {
  savings,
  checking,
  investment,
  credit;

  static AccountType fromName(String? value) => AccountType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => AccountType.savings,
      );

  String get label => switch (this) {
        AccountType.savings => 'Ahorros',
        AccountType.checking => 'Corriente',
        AccountType.investment => 'Inversión',
        AccountType.credit => 'Crédito',
      };
}

enum AccountStatus {
  active,
  frozen,
  closed;

  static AccountStatus fromName(String? value) =>
      AccountStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => AccountStatus.active,
      );
}

class BankAccount {
  const BankAccount({
    required this.id,
    required this.userId,
    required this.type,
    required this.alias,
    required this.numberMasked,
    required this.currency,
    required this.balance,
    required this.available,
    required this.status,
    required this.createdAt,
    this.creditLimit,
  });

  final String id;
  final String userId;
  final AccountType type;
  final String alias;
  final String numberMasked;
  final String currency;
  final Money balance;
  final Money available;
  final AccountStatus status;
  final DateTime createdAt;
  final Money? creditLimit;

  factory BankAccount.fromJson(Map<String, dynamic> json) => BankAccount(
        id: jsonString(json, 'id'),
        userId: jsonString(json, 'userId'),
        type: AccountType.fromName(jsonStringOrNull(json, 'type')),
        alias: jsonString(json, 'alias'),
        numberMasked: jsonString(json, 'numberMasked'),
        currency: jsonString(json, 'currency'),
        balance: Money.fromJson(jsonMap(json, 'balance')),
        available: Money.fromJson(jsonMap(json, 'available')),
        status: AccountStatus.fromName(jsonStringOrNull(json, 'status')),
        createdAt: jsonDate(json, 'createdAt'),
        creditLimit: json['creditLimit'] is Map<String, dynamic>
            ? Money.fromJson(jsonMap(json, 'creditLimit'))
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'type': type.name,
        'alias': alias,
        'numberMasked': numberMasked,
        'currency': currency,
        'balance': balance.toJson(),
        'available': available.toJson(),
        'status': status.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'creditLimit': creditLimit?.toJson(),
      };
}

/// Resumen consolidado de todas las cuentas del usuario.
class AccountsSummary {
  const AccountsSummary({
    required this.accounts,
    required this.totalBalance,
    required this.currency,
  });

  final List<BankAccount> accounts;
  final Money totalBalance;
  final String currency;

  factory AccountsSummary.fromJson(Map<String, dynamic> json) =>
      AccountsSummary(
        accounts: jsonList(json, 'accounts')
            .map(BankAccount.fromJson)
            .toList(growable: false),
        totalBalance: Money.fromJson(jsonMap(json, 'totalBalance')),
        currency: jsonString(json, 'currency', fallback: 'USD'),
      );

  Map<String, dynamic> toJson() => {
        'accounts': accounts.map((a) => a.toJson()).toList(growable: false),
        'totalBalance': totalBalance.toJson(),
        'currency': currency,
      };
}
