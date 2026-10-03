import '../json_utils.dart';
import '../money.dart';

/// Gasto agregado por categoría dentro de un periodo.
class CategorySpend {
  const CategorySpend({
    required this.category,
    required this.amount,
    required this.share,
    required this.transactions,
  });

  final String category;
  final Money amount;

  /// Proporción del gasto total (0..1).
  final double share;
  final int transactions;

  factory CategorySpend.fromJson(Map<String, dynamic> json) => CategorySpend(
        category: jsonString(json, 'category'),
        amount: Money.fromJson(jsonMap(json, 'amount')),
        share: jsonDouble(json, 'share'),
        transactions: jsonInt(json, 'transactions', fallback: 0),
      );

  Map<String, dynamic> toJson() => {
        'category': category,
        'amount': amount.toJson(),
        'share': share,
        'transactions': transactions,
      };
}

class MerchantSpend {
  const MerchantSpend({required this.merchant, required this.amount});

  final String merchant;
  final Money amount;

  factory MerchantSpend.fromJson(Map<String, dynamic> json) => MerchantSpend(
        merchant: jsonString(json, 'merchant'),
        amount: Money.fromJson(jsonMap(json, 'amount')),
      );

  Map<String, dynamic> toJson() => {
        'merchant': merchant,
        'amount': amount.toJson(),
      };
}

/// Mensaje generado a partir del comportamiento del usuario.
class InsightMessage {
  const InsightMessage({
    required this.id,
    required this.title,
    required this.body,
    this.tone = 'neutral',
    this.action,
  });

  final String id;
  final String title;
  final String body;

  /// `positive` | `neutral` | `warning`
  final String tone;
  final String? action;

  factory InsightMessage.fromJson(Map<String, dynamic> json) => InsightMessage(
        id: jsonString(json, 'id'),
        title: jsonString(json, 'title'),
        body: jsonString(json, 'body'),
        tone: jsonString(json, 'tone', fallback: 'neutral'),
        action: jsonStringOrNull(json, 'action'),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'tone': tone,
        'action': action,
      };
}

/// Analítica de gasto generada dinámicamente por el backend.
class SpendingInsights {
  const SpendingInsights({
    required this.periodStart,
    required this.periodEnd,
    required this.income,
    required this.expenses,
    required this.net,
    required this.currency,
    required this.byCategory,
    required this.topMerchants,
    required this.savingsRate,
    required this.changeVsPrevious,
    required this.transactionCount,
    required this.messages,
    required this.generatedAt,
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final Money income;
  final Money expenses;
  final Money net;
  final String currency;
  final List<CategorySpend> byCategory;
  final List<MerchantSpend> topMerchants;

  /// Tasa de ahorro = neto / ingresos (0..1, puede ser negativa).
  final double savingsRate;

  /// Variación del gasto vs. periodo anterior (-1..+∞).
  final double changeVsPrevious;
  final int transactionCount;
  final List<InsightMessage> messages;
  final DateTime generatedAt;

  /// Devuelve una copia con los mensajes generados.
  SpendingInsights withMessages(List<InsightMessage> messages) =>
      SpendingInsights(
        periodStart: periodStart,
        periodEnd: periodEnd,
        income: income,
        expenses: expenses,
        net: net,
        currency: currency,
        byCategory: byCategory,
        topMerchants: topMerchants,
        savingsRate: savingsRate,
        changeVsPrevious: changeVsPrevious,
        transactionCount: transactionCount,
        messages: messages,
        generatedAt: generatedAt,
      );

  factory SpendingInsights.fromJson(Map<String, dynamic> json) =>
      SpendingInsights(
        periodStart: jsonDate(json, 'periodStart'),
        periodEnd: jsonDate(json, 'periodEnd'),
        income: Money.fromJson(jsonMap(json, 'income')),
        expenses: Money.fromJson(jsonMap(json, 'expenses')),
        net: Money.fromJson(jsonMap(json, 'net')),
        currency: jsonString(json, 'currency', fallback: 'USD'),
        byCategory: jsonList(json, 'byCategory')
            .map(CategorySpend.fromJson)
            .toList(growable: false),
        topMerchants: jsonList(json, 'topMerchants')
            .map(MerchantSpend.fromJson)
            .toList(growable: false),
        savingsRate: jsonDouble(json, 'savingsRate'),
        changeVsPrevious: jsonDouble(json, 'changeVsPrevious'),
        transactionCount: jsonInt(json, 'transactionCount', fallback: 0),
        messages: jsonList(json, 'messages')
            .map(InsightMessage.fromJson)
            .toList(growable: false),
        generatedAt: jsonDate(json, 'generatedAt'),
      );

  Map<String, dynamic> toJson() => {
        'periodStart': periodStart.toUtc().toIso8601String(),
        'periodEnd': periodEnd.toUtc().toIso8601String(),
        'income': income.toJson(),
        'expenses': expenses.toJson(),
        'net': net.toJson(),
        'currency': currency,
        'byCategory': byCategory.map((c) => c.toJson()).toList(growable: false),
        'topMerchants':
            topMerchants.map((m) => m.toJson()).toList(growable: false),
        'savingsRate': savingsRate,
        'changeVsPrevious': changeVsPrevious,
        'transactionCount': transactionCount,
        'messages': messages.map((m) => m.toJson()).toList(growable: false),
        'generatedAt': generatedAt.toUtc().toIso8601String(),
      };
}