import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neobank_core/neobank_core.dart';

import '../../../shared/widgets/app_widgets.dart';
import '../application/accounts_controller.dart';

/// Lista de cuentas con saldo consolidado.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(accountsSummaryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mis cuentas')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(accountsSummaryProvider),
        child: AsyncValueView(
          value: async,
          onRetry: () async => ref.invalidate(accountsSummaryProvider),
          builder: (result) {
            final accounts = result.summary.accounts;
            if (accounts.isEmpty) {
              return const EmptyView(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Aún no tienes cuentas',
                subtitle: 'Crea una cuenta para empezar a operar.',
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (result.fromCache)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: _CacheNotice(),
                  ),
                _TotalCard(summary: result.summary),
                const SizedBox(height: 20),
                for (final account in accounts) ...[
                  _AccountTile(account: account),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CacheNotice extends StatelessWidget {
  const _CacheNotice();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 16, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mostrando información guardada. Se actualizará al recuperar la conexión.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      );
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.summary});

  final AccountsSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Balance total', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text(
            summary.totalBalance.format(),
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${summary.accounts.length} cuentas',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account});

  final BankAccount account;

  IconData get _icon => switch (account.type) {
        AccountType.savings => Icons.savings_outlined,
        AccountType.checking => Icons.account_balance_wallet_outlined,
        AccountType.investment => Icons.trending_up_rounded,
        AccountType.credit => Icons.credit_card_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCredit = account.type == AccountType.credit;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => context.push('/accounts/${account.id}'),
        leading: CircleAvatar(
          backgroundColor: scheme.secondaryContainer,
          child: Icon(_icon, color: scheme.onSecondaryContainer),
        ),
        title: Text(
          account.alias,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${account.type.label} · ${account.numberMasked}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            MoneyText(
              money: account.balance,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (isCredit && account.creditLimit != null)
              Text(
                'Cupo ${account.creditLimit!.format()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
