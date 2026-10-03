import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neobank_core/neobank_core.dart';

import '../../../core/error/app_exception.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../accounts/application/accounts_controller.dart';
import '../../config/application/bootstrap_controller.dart';
import '../../fx/data/fx_repository.dart';

/// Tarjeta principal con el saldo consolidado.
class HeroBalanceModule extends ConsumerWidget {
  const HeroBalanceModule({required this.module, super.key});

  final HomeModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(accountsSummaryProvider);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primary.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: async.when(
        loading: () => const SizedBox(
          height: 96,
          child: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
        error: (error, _) => _BalanceError(error: error),
        data: (result) {
          final summary = result.summary;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    module.title ?? 'Tu dinero',
                    style: TextStyle(
                      color: scheme.onPrimary.withValues(alpha: 0.85),
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  if (result.fromCache)
                    Tooltip(
                      message: 'Mostrando datos guardados',
                      child: Icon(Icons.cloud_off_rounded,
                          size: 16, color: scheme.onPrimary),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                summary.totalBalance.format(),
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: summary.accounts
                    .take(3)
                    .map(
                      (account) => _AccountChip(account: account),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.go('/accounts'),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onPrimary,
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Ver mis cuentas'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BalanceError extends StatelessWidget {
  const _BalanceError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final message = error is AppException
        ? (error as AppException).message
        : 'No se pudo cargar el saldo';
    return SizedBox(
      height: 96,
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({required this.account});

  final BankAccount account;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${account.alias} · ${account.balance.format()}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

/// Accesos rápidos configurables desde el backend.
class QuickActionsModule extends StatelessWidget {
  const QuickActionsModule({required this.module, super.key});

  final HomeModule module;

  static const Map<String, (IconData, String, String?)> _catalog = {
    'transfer': (Icons.swap_horiz_rounded, 'Transferir', '/transfer'),
    'pay': (Icons.receipt_long_rounded, 'Pagar', null),
    'topup': (Icons.add_card_rounded, 'Recargar', null),
    'fx': (Icons.currency_exchange_rounded, 'Divisas', '/fx'),
  };

  @override
  Widget build(BuildContext context) {
    final items = (module.config['items'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .toList() ??
        const ['transfer', 'pay', 'topup', 'fx'];
    return Row(
      children: items
          .map((key) {
            final entry = _catalog[key] ?? _catalog['pay']!;
            return Expanded(
              child: _QuickActionButton(
                icon: entry.$1,
                label: entry.$2,
                route: entry.$3,
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String? route;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (route != null) {
          context.go(route!);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label estará disponible pronto')),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: scheme.onSecondaryContainer),
            ),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

/// Micro-app de divisas embebida en el home.
class FxWidgetModule extends ConsumerWidget {
  const FxWidgetModule({required this.module, super.key});

  final HomeModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final from = module.config['defaultFrom']?.toString() ?? 'USD';
    final to = module.config['defaultTo']?.toString() ?? 'EUR';
    final rates = ref.watch(fxRatesProvider(from));
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.go('/fx'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.currency_exchange_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    module.title ?? 'Divisas',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 12),
              rates.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text(
                  error is AppException
                      ? error.message
                      : 'Tasas no disponibles',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                data: (data) {
                  final rate = data.rateFor(to);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '1 $from',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward_rounded, size: 16),
                      ),
                      Text(
                        rate == null ? '—' : '${rate.toStringAsFixed(4)} $to',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (data.stale) ...[
                        const SizedBox(width: 8),
                        const _StaleBadge(),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaleBadge extends StatelessWidget {
  const _StaleBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('cache', style: TextStyle(fontSize: 10)),
      );
}

/// Carrusel horizontal de ofertas personalizadas.
class OffersModule extends ConsumerWidget {
  const OffersModule({required this.module, super.key});

  final HomeModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(offersProvider);
    if (offers.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: module.title ?? 'Para ti'),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: offers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _OfferCard(offer: offers[index]),
          ),
        ),
      ],
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer});

  final Offer offer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: scheme.surfaceContainerHigh,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            offer.title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              offer.description,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (offer.ctaLabel != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Oferta: ${offer.title}')),
                ),
                child: Text(offer.ctaLabel!),
              ),
            ),
        ],
      ),
    );
  }
}

/// Módulo de insights con una sparkline real del saldo.
class InsightsModule extends ConsumerWidget {
  const InsightsModule({required this.module, super.key});

  final HomeModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(accountsSummaryProvider).value?.summary;
    final account = _primaryAccount(summary?.accounts);
    if (account == null) return const SizedBox.shrink();
    final transactions = ref.watch(transactionsProvider(account.id));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              module.title ?? 'Insights del mes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            transactions.when(
              loading: () => const SizedBox(
                height: 60,
                child: Center(child: LinearProgressIndicator()),
              ),
              error: (error, _) => Text(
                'Sin datos suficientes',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              data: (page) {
                final balances = page.items.reversed
                    .map((transaction) => transaction.balanceAfter.amount)
                    .toList(growable: false);
                if (balances.length < 2) {
                  return Text(
                    'Aún no hay suficientes movimientos.',
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                }
                final credits = page.items
                    .where((transaction) => transaction.isCredit)
                    .fold<int>(
                      0,
                      (sum, transaction) =>
                          sum + transaction.amount.minorUnits,
                    );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 64,
                      child: CustomPaint(
                        painter: _SparklinePainter(
                          values: balances,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        size: Size.infinite,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ingresos recientes: ${Money(credits, account.currency).format()}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  BankAccount? _primaryAccount(List<BankAccount>? accounts) {
    if (accounts == null) return null;
    for (final account in accounts) {
      if (account.type != AccountType.credit) return account;
    }
    return null;
  }
}

/// Tarjeta promocional (p. ej. adelanto de salario).
class PromoModule extends StatelessWidget {
  const PromoModule({required this.module, super.key});

  final HomeModule module;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt_rounded, color: scheme.onTertiaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module.title ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
                if (module.subtitle != null)
                  Text(
                    module.subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Adelanto de salario solicitado')),
            ),
            child: const Text('Activar'),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = (max - min) == 0 ? 1 : (max - min);
    final stepX = size.width / (values.length - 1);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = stepX * i;
      final y = size.height - ((values[i] - min) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
