import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

/// Panel de desarrollador para demostrar comportamiento ante red degradada.
class NetworkSimulatorScreen extends ConsumerWidget {
  const NetworkSimulatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conditions = ref.watch(networkConditionsProvider);
    final notifier = ref.read(networkConditionsProvider.notifier);
    final deviceOnline = ref.watch(deviceOnlineProvider).value ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('Simulador de red')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                deviceOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              ),
              title: const Text('Conectividad del dispositivo'),
              subtitle: Text(deviceOnline ? 'En línea' : 'Sin conexión'),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: conditions.offline,
            onChanged: notifier.setOffline,
            title: const Text('Modo offline'),
            subtitle: const Text(
              'Fuerza los errores de red para probar caché y recuperación.',
            ),
            secondary: const Icon(Icons.cloud_off_rounded),
          ),
          const Divider(),
          _SliderTile(
            icon: Icons.timer_outlined,
            title: 'Latencia',
            valueLabel: '${conditions.latency.inMilliseconds} ms',
            value: conditions.latency.inMilliseconds.toDouble(),
            min: 0,
            max: 5000,
            divisions: 10,
            onChanged: (value) =>
                notifier.setLatency(Duration(milliseconds: value.round())),
          ),
          _SliderTile(
            icon: Icons.error_outline_rounded,
            title: 'Tasa de fallos',
            valueLabel: '${(conditions.failureRate * 100).round()}%',
            value: conditions.failureRate,
            min: 0,
            max: 1,
            divisions: 10,
            onChanged: notifier.setFailureRate,
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: notifier.reset,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Restaurar red normal'),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¿Qué observar?',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Con offline verás datos en caché y un banner superior.\n'
                    '• Con latencia alta aparecerán estados de carga.\n'
                    '• Con fallos verás reintentos automáticos con backoff.\n'
                    '• Al restaurar, la app se recupera sin reiniciar.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.icon,
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ListTile(
            leading: Icon(icon),
            title: Text(title),
            trailing: Text(
              valueLabel,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      );
}
