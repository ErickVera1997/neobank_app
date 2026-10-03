import '../json_utils.dart';
import '../money.dart';

enum TransactionType {
  debit,
  credit;

  static TransactionType fromName(String? value) =>
      TransactionType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => TransactionType.debit,
      );
}

enum TransactionStatus {
  posted,
  pending,
  reversed;

  static TransactionStatus fromName(String? value) =>
      TransactionStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => TransactionStatus.posted,
      );
}

class BankTransaction {
  const BankTransaction({
    required this.id,
    required this.accountId,
    required this.type,
    required this.category,
    required this.description,
    required this.amount,
    required this.balanceAfter,
    required this.status,
    required this.createdAt,
    this.merchant,
  });

  final String id;
  final String accountId;
  final TransactionType type;
  final String category;
  final String description;
  final Money amount;
  final Money balanceAfter;
  final TransactionStatus status;
  final DateTime createdAt;
  final String? merchant;

  bool get isCredit => type == TransactionType.credit;

  factory BankTransaction.fromJson(Map<String, dynamic> json) =>
      BankTransaction(
        id: jsonString(json, 'id'),
        accountId: jsonString(json, 'accountId'),
        type: TransactionType.fromName(jsonStringOrNull(json, 'type')),
        category: jsonString(json, 'category', fallback: 'general'),
        description: jsonString(json, 'description'),
        amount: Money.fromJson(jsonMap(json, 'amount')),
        balanceAfter: Money.fromJson(jsonMap(json, 'balanceAfter')),
        status: TransactionStatus.fromName(jsonStringOrNull(json, 'status')),
        createdAt: jsonDate(json, 'createdAt'),
        merchant: jsonStringOrNull(json, 'merchant'),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountId': accountId,
        'type': type.name,
        'category': category,
        'description': description,
        'amount': amount.toJson(),
        'balanceAfter': balanceAfter.toJson(),
        'status': status.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'merchant': merchant,
      };
}

/// Página de movimientos con paginación por cursor.
class TransactionPage {
  const TransactionPage({required this.items, this.nextCursor});

  final List<BankTransaction> items;
  final String? nextCursor;

  factory TransactionPage.fromJson(Map<String, dynamic> json) =>
      TransactionPage(
        items: jsonList(json, 'items')
            .map(BankTransaction.fromJson)
            .toList(growable: false),
        nextCursor: jsonStringOrNull(json, 'nextCursor'),
      );

  Map<String, dynamic> toJson() => {
        'items': items.map((t) => t.toJson()).toList(growable: false),
        'nextCursor': nextCursor,
      };
}
