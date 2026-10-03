import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neobank_core/neobank_core.dart';

import '../../../core/error/app_exception.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../application/accounts_controller.dart';
import '../data/accounts_repository.dart';

/// Detalle de cuenta con movimientos paginados.
class AccountDetailScreen extends ConsumerStatefulWidget {
  const AccountDetailScreen({required this.accountId, super.key});

  final String accountId;

  @override
  ConsumerState<AccountDetailScreen> createState() =>
      _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  final List<BankTransaction> _extra = [];
  String? _cursor;
  bool _loadingMore = false;

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountDetailProvider(widget.accountId));
    final transactions = ref.watch(transactionsProvider(widget.accountId));

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de cuenta')),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _extra.clear();
            _cursor = null;
          });
          ref.invalidate(accountDetailProvider(widget.accountId));
          ref.invalidate(transactionsProvider(widget.accountId));
        },
        child: AsyncValueView(
          value: account,
          onRetry: () async =>
              ref.invalidate(accountDetailProvider(widget.accountId)),
          builder: (data) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _AccountHeader(account: data),
              const SizedBox(height: 20),
              SectionHeader(
                title: 'Movimientos',
                action: TextButton(
                  onPressed: () => context.push('/transfer'),
                  child: const Text('Transferir'),
                ),
              ),
              transactions.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: LoadingView(),
                ),
                error: (error, _) => ErrorView(
                  error: error,
                  onRetry: () async =>
                      ref.invalidate(transactionsProvider(widget.accountId)),
                ),
                data: (page) {
                  final items = [...page.items, ..._extra];
                  _cursor = page.nextCursor;
                  if (items.isEmpty) {
                    return const EmptyView(
                      icon: Icons.receipt_long_outlined,
                      title: 'Sin movimientos',
                      subtitle: 'Aquí verás tus transacciones.',
                    );
                  }
                  return Column(
                    children: [
                      for (final transaction in items)
                        _TransactionTile(transaction: transaction),
                      if (_cursor != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: OutlinedButton(
                            onPressed: _loadingMore ? null : _loadMore,
                            child: _loadingMore
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Cargar más'),
                          ),
                        ),
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

  Future<void> _loadMore() async {
    final cursor = _cursor;
    if (cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(accountsRepositoryProvider)
          .transactions(widget.accountId, cursor: cursor);
      setState(() {
        _extra.addAll(page.items);
        _cursor = page.nextCursor;
      });
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.account});

  final BankAccount account;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primary.withValues(alpha: 0.8)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            account.alias,
            style: TextStyle(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '${account.type.label} · ${account.numberMasked}',
            style: TextStyle(
              color: scheme.onPrimary.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            account.balance.format(),
            style: TextStyle(
              color: scheme.onPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Disponible ${account.available.format()}',
            style: TextStyle(
              color: scheme.onPrimary.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final BankTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCredit = transaction.isCredit;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor:
            isCredit ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        child: Icon(
          isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
          size: 18,
          color: isCredit ? scheme.onPrimaryContainer : scheme.onSurface,
        ),
      ),
      title: Text(
        transaction.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${transaction.merchant ?? transaction.category} · '
        '${_formatDate(transaction.createdAt)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: MoneyText(
        money: transaction.amount,
        signed: true,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}
