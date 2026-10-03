import 'package:neobank_core/neobank_core.dart';

import '../data/store.dart';

/// Genera analítica y mensajes personalizados a partir de los movimientos
/// reales del usuario. Todo el cálculo es dinámico: no hay textos estáticos
/// por usuario.
class InsightsService {
  const InsightsService(this._store);

  final Store _store;

  /// Categorías que representan movimientos internos o aperturas y que no
  /// deben contar como gasto ni como ingreso.
  static const Set<String> _neutralCategories = {
    'transfer',
    'opening',
    'payment',
  };

  SpendingInsights monthly(String userId, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final periodStart = DateTime(reference.year, reference.month);
    final periodEnd = DateTime(reference.year, reference.month + 1);
    final previousStart = DateTime(reference.year, reference.month - 1);

    final current = _store.transactionsForUser(
      userId,
      from: periodStart,
      to: periodEnd,
    );
    final previous = _store.transactionsForUser(
      userId,
      from: previousStart,
      to: periodStart,
    );

    final currency = _currencyFor(userId);
    final accounting = _aggregate(current, currency);
    final previousAccounting = _aggregate(previous, currency);

    final changeVsPrevious = previousAccounting.expenses > 0
        ? (accounting.expenses - previousAccounting.expenses) /
            previousAccounting.expenses
        : 0.0;
    final savingsRate = accounting.income > 0
        ? (accounting.income - accounting.expenses) / accounting.income
        : 0.0;

    final insights = SpendingInsights(
      periodStart: periodStart,
      periodEnd: periodEnd,
      income: Money(accounting.income, currency),
      expenses: Money(accounting.expenses, currency),
      net: Money(accounting.income - accounting.expenses, currency),
      currency: currency,
      byCategory: accounting.byCategory,
      topMerchants: accounting.topMerchants,
      savingsRate: savingsRate,
      changeVsPrevious: changeVsPrevious,
      transactionCount: accounting.count,
      messages: const [],
      generatedAt: DateTime.now(),
    );

    return insights.withMessages(_messages(insights));
  }

  _Aggregate _aggregate(List<BankTransaction> transactions, String currency) {
    var income = 0;
    var expenses = 0;
    var count = 0;
    final categories = <String, int>{};
    final categoryCount = <String, int>{};
    final merchants = <String, int>{};

    for (final transaction in transactions) {
      final category = transaction.category;
      if (_neutralCategories.contains(category)) continue;
      count++;
      if (transaction.isCredit) {
        income += transaction.amount.minorUnits;
      } else {
        final magnitude = transaction.amount.abs().minorUnits;
        expenses += magnitude;
        categories.update(
          category,
          (value) => value + magnitude,
          ifAbsent: () => magnitude,
        );
        categoryCount.update(category, (value) => value + 1, ifAbsent: () => 1);
        final merchant = transaction.merchant;
        if (merchant != null && merchant.isNotEmpty) {
          merchants.update(
            merchant,
            (value) => value + magnitude,
            ifAbsent: () => magnitude,
          );
        }
      }
    }

    final byCategory = categories.entries.map((entry) {
      return CategorySpend(
        category: entry.key,
        amount: Money(entry.value, currency),
        share: expenses == 0 ? 0 : entry.value / expenses,
        transactions: categoryCount[entry.key] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.amount.minorUnits.compareTo(a.amount.minorUnits));

    final topMerchants = merchants.entries
        .map((entry) => MerchantSpend(
              merchant: entry.key,
              amount: Money(entry.value, currency),
            ))
        .toList()
      ..sort((a, b) => b.amount.minorUnits.compareTo(a.amount.minorUnits));

    return _Aggregate(
      income: income,
      expenses: expenses,
      count: count,
      byCategory: byCategory.take(6).toList(growable: false),
      topMerchants: topMerchants.take(5).toList(growable: false),
    );
  }

  List<InsightMessage> _messages(SpendingInsights insights) {
    final messages = <InsightMessage>[];

    if (insights.byCategory.isNotEmpty) {
      final top = insights.byCategory.first;
      final share = (top.share * 100).round();
      messages.add(
        InsightMessage(
          id: 'top_category',
          title: 'Tu mayor gasto: ${_label(top.category)}',
          body:
              '${top.amount.format()} este mes ($share% del total). Pregúntame por el detalle.',
          tone: 'neutral',
          action: '¿Cuánto gasté en ${top.category}?',
        ),
      );
    }

    if (insights.changeVsPrevious.abs() >= 0.05) {
      final percent = (insights.changeVsPrevious.abs() * 100).round();
      messages.add(
        InsightMessage(
          id: 'trend',
          title: insights.changeVsPrevious > 0
              ? 'Gastaste $percent% más que el mes pasado'
              : 'Redujiste tu gasto $percent% vs. el mes pasado',
          body: insights.changeVsPrevious > 0
              ? 'Revisa tus categorías principales para encontrar oportunidades de ahorro.'
              : '¡Bien hecho! Mantén el ritmo para cumplir tus metas.',
          tone: insights.changeVsPrevious > 0 ? 'warning' : 'positive',
          action: 'Muéstrame mi análisis del mes',
        ),
      );
    }

    if (insights.savingsRate >= 0.2) {
      messages.add(
        InsightMessage(
          id: 'savings_rate',
          title: 'Tasa de ahorro ${(insights.savingsRate * 100).round()}%',
          body: 'Estás por encima del 20% recomendado. Considera invertir el excedente.',
          tone: 'positive',
          action: '¿Cómo van mis ahorros?',
        ),
      );
    } else if (insights.savingsRate < 0) {
      messages.add(
        const InsightMessage(
          id: 'overspend',
          title: 'Gastaste más de lo que ingresaste',
          body: 'Revisa tus gastos variables para recuperar el equilibrio.',
          tone: 'warning',
          action: 'Muéstrame mi análisis del mes',
        ),
      );
    }

    if (insights.topMerchants.isNotEmpty) {
      final merchant = insights.topMerchants.first;
      messages.add(
        InsightMessage(
          id: 'top_merchant',
          title: 'Comercio frecuente: ${merchant.merchant}',
          body: 'Acumulas ${merchant.amount.format()} aquí este mes.',
          tone: 'neutral',
        ),
      );
    }

    return messages;
  }

  String _currencyFor(String userId) {
    final accounts = _store.accountsForUser(userId);
    return accounts.isEmpty ? 'USD' : accounts.first.currency;
  }

  static String categoryLabel(String category) => _label(category);

  static String _label(String category) => switch (category) {
        'groceries' => 'supermercado',
        'dining' => 'restaurantes',
        'transport' => 'transporte',
        'utilities' => 'servicios',
        'entertainment' => 'entretenimiento',
        'health' => 'salud',
        'shopping' => 'compras',
        'housing' => 'vivienda',
        'salary' => 'salario',
        'freelance' => 'freelance',
        'cashback' => 'cashback',
        'interest' => 'intereses',
        'contribution' => 'aportes',
        'yield' => 'rendimientos',
        'welcome' => 'bono',
        _ => category,
      };
}

class _Aggregate {
  const _Aggregate({
    required this.income,
    required this.expenses,
    required this.count,
    required this.byCategory,
    required this.topMerchants,
  });

  final int income;
  final int expenses;
  final int count;
  final List<CategorySpend> byCategory;
  final List<MerchantSpend> topMerchants;
}