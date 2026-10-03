import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neobank_core/neobank_core.dart';

import '../../../shared/widgets/app_widgets.dart';
import '../data/insights_repository.dart';

/// Panel de analítica generada dinámicamente a partir de los movimientos.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(insightsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu análisis'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(insightsProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(insightsProvider),
        child: AsyncValueView(
          value: async,
          onRetry: () async => ref.invalidate(insightsProvider),
          builder: (insights) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryCard(insights: insights),
              const SizedBox(height: 20),
              if (insights.messages.isNotEmpty) ...[
                const SectionHeader(title: 'Descubrimientos'),
                for (final message in insights.messages) ...[
                  _InsightMessageCard(message: message),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 10),
              ],
              if (insights.byCategory.isNotEmpty) ...[
                const SectionHeader(title: 'Gasto por categoría'),
                _CategoryBreakdown(insights: insights),
                const SizedBox(height: 20),
              ],
              if (insights.topMerchants.isNotEmpty) ...[
                const SectionHeader(title: 'Comercios frecuentes'),
                Card(
                  child: Column(
                    children: insights.topMerchants
                        .map(
                          (merchant) => ListTile(
                            leading: const Icon(Icons.storefront_outlined),
                            title: Text(merchant.merchant),
                            trailing: Text(
                              merchant.amount.format(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.insights});

  final SpendingInsights insights;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final change = insights.changeVsPrevious;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Este mes', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text(
            insights.expenses.format(),
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            'de gastos · ${insights.transactionCount} movimientos',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Ingresos',
                  value: insights.income.format(),
                  color: const Color(0xFF14804A),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Balance',
                  value: insights.net.format(),
                  color: insights.net.isNegative
                      ? scheme.error
                      : scheme.onSurface,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Ahorro',
                  value: '${(insights.savingsRate * 100).round()}%',
                ),
              ),
            ],
          ),
          if (change.abs() >= 0.01) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  change > 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 16,
                  color: change > 0 ? scheme.error : const Color(0xFF14804A),
                ),
                const SizedBox(width: 6),
                Text(
                  '${change > 0 ? '+' : ''}${(change * 100).round()}% vs. mes anterior',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      );
}

class _InsightMessageCard extends StatelessWidget {
  const _InsightMessageCard({required this.message});

  final InsightMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground, icon) = switch (message.tone) {
      'positive' => (
          const Color(0xFFD7F5E3),
          const Color(0xFF0B5D33),
          Icons.trending_up_rounded,
        ),
      'warning' => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          Icons.warning_amber_rounded,
        ),
      _ => (scheme.surfaceContainerHigh, scheme.onSurface, Icons.insights_rounded),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(message.body, style: TextStyle(color: foreground)),
          if (message.action != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push(
                  '/assistant?q=${Uri.encodeComponent(message.action!)}',
                ),
                style: TextButton.styleFrom(foregroundColor: foreground),
                child: const Text('Preguntar al copiloto'),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.insights});

  final SpendingInsights insights;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: insights.byCategory
              .map(
                (category) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              InsightsLabels.fromCategory(category.category),
                            ),
                          ),
                          Text(
                            '${category.amount.format()} '
                            '(${(category.share * 100).round()}%)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: category.share.clamp(0, 1),
                          minHeight: 8,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

/// Traduce categorías técnicas a etiquetas legibles.
abstract final class InsightsLabels {
  static String fromCategory(String category) => switch (category) {
        'groceries' => 'Supermercado',
        'dining' => 'Restaurantes',
        'transport' => 'Transporte',
        'utilities' => 'Servicios',
        'entertainment' => 'Entretenimiento',
        'health' => 'Salud',
        'shopping' => 'Compras',
        'housing' => 'Vivienda',
        'salary' => 'Salario',
        'freelance' => 'Freelance',
        'cashback' => 'Cashback',
        'interest' => 'Intereses',
        _ => category,
      };
}