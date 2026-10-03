import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neobank_core/neobank_core.dart';

import '../../../shared/widgets/app_widgets.dart';
import '../../accounts/application/accounts_controller.dart';
import '../data/transfers_repository.dart';

/// Formulario de transferencias (internas y a terceros).
class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({this.initialFromAccountId, super.key});

  final String? initialFromAccountId;

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController(text: 'Transferencia');
  final _beneficiary = TextEditingController();
  bool _internal = true;
  String? _fromId;
  String? _toId;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _beneficiary.dispose();
    super.dispose();
  }

  Future<void> _submit(List<BankAccount> accounts) async {
    if (!_formKey.currentState!.validate()) return;
    final fromId = _fromId;
    if (fromId == null) {
      _showError('Selecciona una cuenta de origen');
      return;
    }
    final amount = double.tryParse(_amount.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      _showError('Ingresa un monto válido');
      return;
    }
    FocusScope.of(context).unfocus();

    final controller = ref.read(transferControllerProvider.notifier);
    final success = await controller.submit(
      fromAccountId: fromId,
      amountMinor: Money.fromAmount(amount, 'USD').minorUnits,
      description: _description.text.trim().isEmpty
          ? 'Transferencia'
          : _description.text.trim(),
      toAccountId: _internal ? _toId : null,
      beneficiaryName: _internal ? null : _beneficiary.text.trim(),
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transferencia realizada con éxito')),
      );
      controller.reset();
      context.go('/home');
    } else {
      final error = ref.read(transferControllerProvider).error;
      _showError(error is Exception ? '$error' : 'No se pudo transferir');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsSummaryProvider);
    final submitting = ref.watch(transferControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Transferir')),
      body: AsyncValueView(
        value: accounts,
        onRetry: () async => ref.invalidate(accountsSummaryProvider),
        builder: (result) {
          final origin = result.summary.accounts
              .where((account) => account.type != AccountType.credit)
              .toList(growable: false);
          _fromId ??= widget.initialFromAccountId ??
              (origin.isNotEmpty ? origin.first.id : null);
          final destinations = origin
              .where((account) => account.id != _fromId)
              .toList(growable: false);

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Interna')),
                    ButtonSegment(value: false, label: Text('A terceros')),
                  ],
                  selected: {_internal},
                  onSelectionChanged: (selection) =>
                      setState(() => _internal = selection.first),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _fromId,
                  decoration: const InputDecoration(
                    labelText: 'Cuenta de origen',
                  ),
                  items: origin
                      .map(
                        (account) => DropdownMenuItem(
                          value: account.id,
                          child: Text(
                            '${account.alias} · ${account.balance.format()}',
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) => setState(() => _fromId = value),
                  validator: (value) =>
                      value == null ? 'Selecciona una cuenta' : null,
                ),
                const SizedBox(height: 16),
                if (_internal)
                  DropdownButtonFormField<String>(
                    initialValue: _toId,
                    decoration:
                        const InputDecoration(labelText: 'Cuenta destino'),
                    items: destinations
                        .map(
                          (account) => DropdownMenuItem(
                            value: account.id,
                            child: Text(account.alias),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) => setState(() => _toId = value),
                    validator: (value) => _internal && value == null
                        ? 'Selecciona una cuenta'
                        : null,
                  )
                else
                  TextFormField(
                    controller: _beneficiary,
                    decoration: const InputDecoration(
                      labelText: 'Beneficiario',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (value) =>
                        !_internal && (value == null || value.trim().isEmpty)
                            ? 'Ingresa el beneficiario'
                            : null,
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Monto',
                    prefixIcon: Icon(Icons.attach_money_rounded),
                  ),
                  validator: (value) {
                    final amount =
                        double.tryParse((value ?? '').replaceAll(',', '.'));
                    return (amount == null || amount <= 0)
                        ? 'Monto inválido'
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: submitting ? null : () => _submit(origin),
                  icon: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text('Enviar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
