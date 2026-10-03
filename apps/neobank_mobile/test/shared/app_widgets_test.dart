import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neobank_core/neobank_core.dart';
import 'package:neobank_mobile/src/core/error/app_exception.dart';
import 'package:neobank_mobile/src/core/network/network_conditions.dart';
import 'package:neobank_mobile/src/core/providers.dart';
import 'package:neobank_mobile/src/shared/widgets/app_widgets.dart';

class _OfflineConditions extends NetworkConditionsNotifier {
  @override
  NetworkConditions build() => const NetworkConditions(offline: true);
}

void main() {
  testWidgets('MoneyText formatea importes con símbolo', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: MoneyText(money: Money(123456, 'USD'))),
        ),
      ),
    );
    expect(find.text(r'$1,234.56'), findsOneWidget);
  });

  testWidgets('MoneyText con signo muestra + en créditos', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: MoneyText(money: Money(5000, 'USD'), signed: true),
          ),
        ),
      ),
    );
    expect(find.text(r'+$50.00'), findsOneWidget);
  });

  testWidgets('ErrorView muestra mensaje y botón de reintento',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ErrorView(
              error: const AppException(AppErrorKind.server, 'Servicio caído'),
              onRetry: () async {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Servicio caído'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('ConnectivityBanner avisa del modo offline simulado',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkConditionsProvider.overrideWith(_OfflineConditions.new),
          deviceOnlineProvider.overrideWith((ref) => Stream.value(true)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ConnectivityBanner()),
        ),
      ),
    );
    expect(find.text('Modo offline simulado'), findsOneWidget);
  });

  testWidgets('ConnectivityBanner se oculta con red normal', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceOnlineProvider.overrideWith((ref) => Stream.value(true)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ConnectivityBanner()),
        ),
      ),
    );
    expect(find.text('Modo offline simulado'), findsNothing);
    expect(find.text('Sin conexión a Internet'), findsNothing);
  });
}