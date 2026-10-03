import 'package:neobank_core/neobank_core.dart';

import '../data/store.dart';
import '../domain/errors.dart';
import 'fx_service.dart';
import 'insights_service.dart';

/// Copiloto financiero: responde preguntas del usuario usando **sus datos
/// reales** (saldos, movimientos y analítica) y tasas de cambio en vivo.
///
/// El motor de intención es determinista y auditable. El punto de extensión
/// para un LLM es `ask`: basta delegar la clasificación o la redacción a un
/// proveedor externo manteniendo los mismos datos de contexto.
class AssistantService {
  const AssistantService(this._store, this._fx, this._insights);

  final Store _store;
  final FxService _fx;
  final InsightsService _insights;

  static const List<String> suggestions = [
    '¿Cuál es mi saldo?',
    '¿Cuánto gasté este mes?',
    '¿Cuánto gasté en supermercado?',
    '¿Cuánto es 100 USD en EUR?',
    'Muéstrame mis últimos movimientos',
  ];

  Future<AssistantAnswer> ask(String userId, String message) async {
    final normalized = _normalize(message);
    if (normalized.isEmpty) return _help(userId);

    if (_has(normalized, ['hola', 'buenos dias', 'buenas tardes', 'ayuda',
        'que puedes hacer', 'help'])) {
      return _help(userId);
    }
    if (_isFx(normalized)) return _fxAnswer(userId, normalized);
    if (_has(normalized, ['ahorr', 'meta'])) return _savings(userId);
    if (_has(normalized, ['saldo', 'cuanto tengo', 'balance', 'disponible'])) {
      return _balance(userId);
    }
    if (_has(normalized, ['movimiento', 'ultimos', 'transaccion', 'reciente'])) {
      return _movements(userId);
    }
    if (_has(normalized, ['analisis', 'insight', 'como voy', 'resumen'])) {
      return _insightsAnswer(userId);
    }
    final category = _detectCategory(normalized);
    if (category != null) return _categorySpend(userId, category);
    if (_has(normalized, ['gaste', 'gasto', 'gastado', 'cuanto llevo'])) {
      return _spending(userId);
    }
    if (_has(normalized, ['ingres', 'recibi', 'abono', 'nomina', 'gane'])) {
      return _income(userId);
    }
    return _help(userId, fallback: true);
  }

  AssistantAnswer _balance(String userId) {
    final accounts = _store.accountsForUser(userId);
    final currency = accounts.isEmpty ? 'USD' : accounts.first.currency;
    final total = accounts
        .where((account) => account.type != AccountType.credit)
        .fold<int>(0, (sum, account) => sum + account.balance.minorUnits);
    final available = accounts
        .where((account) => account.type != AccountType.credit)
        .fold<int>(0, (sum, account) => sum + account.available.minorUnits);
    return AssistantAnswer(
      reply: 'Tu saldo total es ${Money(total, currency).format()} '
          'en ${accounts.length} cuentas. Disponible: '
          '${Money(available, currency).format()}.',
      intent: 'balance',
      suggestions: const [
        '¿Cuánto gasté este mes?',
        'Muéstrame mis últimos movimientos',
      ],
      card: AssistantCard(
        type: 'balance',
        title: 'Saldo consolidado',
        subtitle: '${accounts.length} cuentas',
        amount: Money(total, currency),
      ),
    );
  }

  AssistantAnswer _spending(String userId) {
    final insights = _insights.monthly(userId);
    return AssistantAnswer(
      reply: 'Este mes gastaste ${insights.expenses.format()} '
          'y recibiste ${insights.income.format()}. '
          'Tu balance del mes es ${insights.net.format()}.',
      intent: 'spending_total',
      suggestions: const [
        '¿Cuánto gasté en supermercado?',
        'Muéstrame mi análisis del mes',
      ],
      card: AssistantCard(
        type: 'balance',
        title: 'Gasto del mes',
        subtitle: '${insights.transactionCount} movimientos',
        amount: insights.expenses,
      ),
    );
  }

  AssistantAnswer _income(String userId) {
    final insights = _insights.monthly(userId);
    return AssistantAnswer(
      reply: 'Este mes recibiste ${insights.income.format()}. '
          'Tu tasa de ahorro es '
          '${(insights.savingsRate * 100).round()}%.',
      intent: 'income',
      suggestions: const ['¿Cómo van mis ahorros?', '¿Cuál es mi saldo?'],
      card: AssistantCard(
        type: 'balance',
        title: 'Ingresos del mes',
        amount: insights.income,
      ),
    );
  }

  AssistantAnswer _categorySpend(String userId, String category) {
    final insights = _insights.monthly(userId);
    final entry = insights.byCategory
        .where((item) => item.category == category)
        .toList();
    final label = InsightsService.categoryLabel(category);
    if (entry.isEmpty) {
      return AssistantAnswer(
        reply: 'No registré gastos en $label este mes.',
        intent: 'spending_category',
        suggestions: const ['¿Cuánto gasté este mes?'],
      );
    }
    final spend = entry.first;
    return AssistantAnswer(
      reply: 'Gastaste ${spend.amount.format()} en $label este mes '
          '(${(spend.share * 100).round()}% de tu gasto total, '
          '${spend.transactions} movimientos).',
      intent: 'spending_category',
      suggestions: const ['¿Cuánto gasté este mes?', 'Muéstrame mi análisis del mes'],
      card: AssistantCard(
        type: 'balance',
        title: 'Gasto en $label',
        subtitle: '${spend.transactions} movimientos',
        amount: spend.amount,
      ),
    );
  }

  AssistantAnswer _savings(String userId) {
    final accounts = _store.accountsForUser(userId);
    final savings = accounts
        .where((account) => account.type == AccountType.savings)
        .toList(growable: false);
    if (savings.isEmpty) {
      return const AssistantAnswer(
        reply: 'Aún no tienes una cuenta de ahorros. Puedo mostrarte cómo '
            'crear una meta desde el home.',
        intent: 'savings',
        suggestions: ['¿Cuál es mi saldo?', '¿Cuánto gasté este mes?'],
      );
    }
    final currency = savings.first.currency;
    final total = savings.fold<int>(
      0,
      (sum, account) => sum + account.balance.minorUnits,
    );
    return AssistantAnswer(
      reply: 'Tus ahorros suman ${Money(total, currency).format()} '
          'en ${savings.length} cuenta(s).',
      intent: 'savings',
      suggestions: const ['¿Cuánto gasté este mes?', '¿Cuál es mi saldo?'],
      card: AssistantCard(
        type: 'balance',
        title: 'Tus ahorros',
        subtitle: savings.map((account) => account.alias).join(' · '),
        amount: Money(total, currency),
      ),
    );
  }

  AssistantAnswer _movements(String userId) {
    final transactions = _store.transactionsForUser(userId, limit: 5);
    if (transactions.isEmpty) {
      return const AssistantAnswer(
        reply: 'Todavía no tienes movimientos registrados.',
        intent: 'movements',
        suggestions: ['¿Cuál es mi saldo?'],
      );
    }
    final lines = transactions
        .map(
          (transaction) =>
              '• ${transaction.description}: ${transaction.amount.format()}',
        )
        .join('\n');
    return AssistantAnswer(
      reply: 'Estos son tus últimos movimientos:\n$lines',
      intent: 'movements',
      suggestions: const ['¿Cuánto gasté este mes?', '¿Cuál es mi saldo?'],
      card: AssistantCard(
        type: 'transactions',
        title: 'Últimos movimientos',
        transactions: transactions,
      ),
    );
  }

  AssistantAnswer _insightsAnswer(String userId) {
    final insights = _insights.monthly(userId);
    final summary = insights.messages.isEmpty
        ? 'Sin novedades este mes.'
        : insights.messages.map((message) => '• ${message.title}').join('\n');
    return AssistantAnswer(
      reply: 'Tu análisis del mes:\n$summary',
      intent: 'insights',
      suggestions: const ['¿Cuánto gasté en supermercado?', '¿Cuál es mi saldo?'],
      card: AssistantCard(
        type: 'insights',
        title: 'Análisis del mes',
        insights: insights,
      ),
    );
  }

  Future<AssistantAnswer> _fxAnswer(String userId, String normalized) async {
    final currencies = _currenciesIn(normalized);
    final amount = _amountIn(normalized) ?? 1;
    final from = currencies.isNotEmpty ? currencies.first : 'USD';
    final to = currencies.length > 1
        ? currencies[1]
        : (from == 'USD' ? 'EUR' : 'USD');
    try {
      final conversion = await _fx.convert(
        from: from,
        to: to,
        amountMinor: Money.fromAmount(amount, from).minorUnits,
      );
      return AssistantAnswer(
        reply: '${conversion.amount.format()} equivalen a '
            '${conversion.result.format()} '
            '(tasa ${conversion.rate.toStringAsFixed(4)}'
            '${conversion.stale ? ', dato en caché' : ''}).',
        intent: 'fx_conversion',
        suggestions: const ['¿Cuál es mi saldo?', '¿Cuánto gasté este mes?'],
        card: AssistantCard(
          type: 'conversion',
          title: 'Conversión de divisas',
          subtitle: 'Tasa ${conversion.rate.toStringAsFixed(4)}',
          conversion: conversion,
        ),
      );
    } on ApiException {
      return const AssistantAnswer(
        reply: 'No pude obtener tasas de cambio en este momento. '
            'Inténtalo de nuevo en unos segundos.',
        intent: 'fx_conversion',
        suggestions: ['¿Cuál es mi saldo?'],
      );
    }
  }

  AssistantAnswer _help(String userId, {bool fallback = false}) {
    return AssistantAnswer(
      reply: fallback
          ? 'No estoy seguro de haber entendido. Puedo ayudarte con tu saldo, '
              'tus gastos por categoría, tus ahorros, tus últimos movimientos '
              'y conversiones de divisas.'
          : '¡Hola! Soy tu copiloto financiero. Pregúntame por tu saldo, tus '
              'gastos, tus ahorros, tus movimientos o una conversión de divisas.',
      intent: 'help',
      suggestions: suggestions,
    );
  }

  bool _isFx(String text) {
    const keywords = [
      'cambia', 'convert', 'cuanto es', 'divisa', 'dolar', 'euro', 'libra',
      'usd', 'eur', 'gbp', 'cop', 'mxn', 'brl',
    ];
    return _has(text, keywords);
  }

  List<String> _currenciesIn(String text) {
    const names = {
      'dolar': 'USD',
      'dolares': 'USD',
      'euro': 'EUR',
      'euros': 'EUR',
      'libra': 'GBP',
      'libras': 'GBP',
      'peso': 'COP',
      'pesos': 'COP',
      'real': 'BRL',
      'reales': 'BRL',
    };
    final found = <String>[];
    final codeRegex = RegExp(r'\b(USD|EUR|GBP|COP|MXN|BRL)\b');
    for (final match in codeRegex.allMatches(text.toUpperCase())) {
      found.add(match.group(1)!);
    }
    for (final entry in names.entries) {
      if (text.contains(entry.key)) found.add(entry.value);
    }
    final unique = <String>[];
    for (final currency in found) {
      if (!unique.contains(currency)) unique.add(currency);
    }
    return unique;
  }

  double? _amountIn(String text) {
    final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(text);
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', '.'));
  }

  String? _detectCategory(String text) {
    const mapping = {
      'groceries': ['supermercado', 'mercado', 'groceries', 'comestible'],
      'dining': ['restaurante', 'comida', 'cena', 'cafe', 'dining'],
      'transport': ['transporte', 'taxi', 'uber', 'combustible', 'gasolina'],
      'utilities': ['servicio', 'luz', 'agua', 'internet', 'plan'],
      'entertainment': ['entretenimiento', 'streaming', 'cine', 'netflix'],
      'health': ['salud', 'farmacia', 'medico'],
      'shopping': ['ropa', 'compra', 'shopping', 'zara'],
      'housing': ['vivienda', 'arriendo', 'renta'],
    };
    for (final entry in mapping.entries) {
      if (_has(text, entry.value)) return entry.key;
    }
    return null;
  }

  bool _has(String text, List<String> keywords) =>
      keywords.any(text.contains);

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[áàäâ]'), 'a')
      .replaceAll(RegExp('[éèëê]'), 'e')
      .replaceAll(RegExp('[íìïî]'), 'i')
      .replaceAll(RegExp('[óòöô]'), 'o')
      .replaceAll(RegExp('[úùüû]'), 'u')
      .replaceAll('ñ', 'n')
      .trim();
}