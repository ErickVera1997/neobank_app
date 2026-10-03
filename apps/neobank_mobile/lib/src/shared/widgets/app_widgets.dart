import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neobank_core/neobank_core.dart';

import '../../core/error/app_exception.dart';
import '../../core/providers.dart';

/// Renderiza un `AsyncValue` con estados de carga/error reutilizables.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    required this.value,
    required this.builder,
    this.onRetry,
    this.loading,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final Future<void> Function()? onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) => value.when(
        data: builder,
        loading: () => loading ?? const LoadingView(),
        error: (error, stackTrace) => ErrorView(error: error, onRetry: onRetry),
      );
}

class LoadingView extends StatelessWidget {
  const LoadingView({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(message!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView({required this.error, this.onRetry, super.key});

  final Object error;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final message =
        error is AppException ? (error as AppException).message : 'Algo salió mal.';
    final canRetry = error is! AppException || (error as AppException).isRetryable;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (onRetry != null && canRetry) ...[
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: () => onRetry!(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    required this.icon,
    required this.title,
    this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      );
}

/// Banner que informa estados de red degradada (offline o simulada).
class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conditions = ref.watch(networkConditionsProvider);
    final deviceOnline = ref.watch(deviceOnlineProvider).value ?? true;
    final scheme = Theme.of(context).colorScheme;

    final String? label;
    if (conditions.offline) {
      label = 'Modo offline simulado';
    } else if (!deviceOnline) {
      label = 'Sin conexión a Internet';
    } else if (conditions.isDegraded) {
      label = 'Red degradada (latencia ${conditions.latency.inMilliseconds} ms)';
    } else {
      label = null;
    }
    if (label == null) return const SizedBox.shrink();

    return Material(
      color: scheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 18, color: scheme.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: scheme.onErrorContainer, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Texto monetario con signo y color coherentes.
class MoneyText extends StatelessWidget {
  const MoneyText({
    required this.money,
    this.signed = false,
    this.style,
    super.key,
  });

  final Money money;
  final bool signed;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isNegative = money.isNegative;
    final color = !signed
        ? scheme.onSurface
        : (isNegative ? scheme.onSurface : const Color(0xFF14804A));
    final prefix = !signed ? '' : (isNegative ? '' : '+');
    return Text(
      '$prefix${money.abs().format()}',
      style: (style ?? Theme.of(context).textTheme.titleMedium)?.copyWith(
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, this.action, super.key});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (action != null) action!,
          ],
        ),
      );
}
