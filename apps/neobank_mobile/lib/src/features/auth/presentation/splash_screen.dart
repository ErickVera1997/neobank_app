import 'package:flutter/material.dart';

/// Pantalla de arranque mientras se restaura la sesión.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_rounded,
                size: 64, color: scheme.onPrimary),
            const SizedBox(height: 16),
            Text(
              'Neobank',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: scheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
