import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neobank_core/neobank_core.dart';

import '../../../core/error/app_exception.dart';
import '../data/fx_repository.dart';

/// Micro-app de conversión de divisas con tasas reales.
class FxScreen extends ConsumerStatefulWidget {
  const FxScreen({super.key});

  @override
  ConsumerState<FxScreen> createState() => _FxScreenState();
}

class _FxScreenState extends ConsumerState<FxScreen> {
  static const List<String> _currencies = [
    'USD',
    'EUR',
    'GBP',
    'COP',
    'MXN',
    'BRL',
  ];

  String _from = 'USD';
  String _to = 'EUR';
  final TextEditingController _amount = TextEditingController(text: '100');
  FxConversion? _result;
  bool _loading = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _convert() async {
    final amount = double.tryParse(_amount.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      _showError('Ingresa un monto válido');
      return;
    }
    setState(() => _loading = true);
    try {
      final conversion = await ref.read(fxRepositoryProvider).convert(
            from: _from,
            to: _to,
            amountMinor: Money.fromAmount(amount, _from).minorUnits,
          );
      setState(() => _result = conversion);
    } on AppException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final rates = ref.watch(fxRatesProvider(_from));
    return Scaffold(
      appBar: AppBar(title: const Text('Conversión de divisas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _CurrencyDropdown(
                          label: 'Desde',
                          value: _from,
                          currencies: _currencies,
                          onChanged: (value) => setState(() {
                            _from = value;
                            _result = null;
                          }),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() {
                          final tmp = _from;
                          _from = _to;
                          _to = tmp;
                          _result = null;
                        }),
                        icon: const Icon(Icons.swap_horiz_rounded),
                      ),
                      Expanded(
                        child: _CurrencyDropdown(
                          label: 'Hacia',
                          value: _to,
                          currencies: _currencies,
                          onChanged: (value) => setState(() {
                            _to = value;
                            _result = null;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Monto en $_from',
                      prefixIcon: const Icon(Icons.attach_money_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _convert,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.calculate_rounded),
                      label: const Text('Convertir'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          rates.when(
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
            ),
            error: (error, _) => Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_off_rounded),
                title: const Text('Tasas no disponibles'),
                subtitle: Text(
                  error is AppException ? error.message : 'Intenta más tarde',
                ),
              ),
            ),
            data: (data) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Tasas base ${data.base}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        if (data.stale)
                          Chip(
                            label: const Text('desactualizado'),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .tertiaryContainer,
                          ),
                      ],
                    ),
                    Text(
                      'Fuente: ${data.source}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Divider(height: 24),
                    for (final entry in data.rates.entries.take(6))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Text('1 ${data.base} ='),
                            const Spacer(),
                            Text(
                              '${entry.value.toStringAsFixed(4)} ${entry.key}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            _ResultCard(conversion: _result!),
          ],
        ],
      ),
    );
  }
}

class _CurrencyDropdown extends StatelessWidget {
  const _CurrencyDropdown({
    required this.label,
    required this.value,
    required this.currencies,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> currencies;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: currencies
            .map(
              (currency) => DropdownMenuItem(
                value: currency,
                child: Text(currency),
              ),
            )
            .toList(growable: false),
        onChanged: (value) => value == null ? null : onChanged(value),
      );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.conversion});

  final FxConversion conversion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            conversion.result.format(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '${conversion.amount.format()} · tasa ${conversion.rate.toStringAsFixed(4)}'
            '${conversion.stale ? ' (caché)' : ''}',
            style: TextStyle(color: scheme.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}
