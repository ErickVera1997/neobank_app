import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neobank_core/neobank_core.dart';
import 'package:neobank_mobile/src/features/accounts/application/accounts_controller.dart';
import 'package:neobank_mobile/src/features/accounts/data/accounts_repository.dart';
import 'package:neobank_mobile/src/features/home/presentation/home_modules.dart';

BankAccount _account() => BankAccount(
      id: 'acc_1',
      userId: 'u1',
      type: AccountType.checking,
      alias: 'Cuenta principal',
      numberMasked: '**** 1190',
      currency: 'USD',
      balance: const Money(123456, 'USD'),
      available: const Money(123456, 'USD'),
      status: AccountStatus.active,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  testWidgets('HeroBalanceModule muestra el saldo consolidado',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsSummaryProvider.overrideWith(
            (ref) async => AccountsResult(
              summary: AccountsSummary(
                accounts: [_account()],
                totalBalance: const Money(123456, 'USD'),
                currency: 'USD',
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: HeroBalanceModule(
              module: const HomeModule(
                id: 'hero',
                type: HomeModuleType.heroBalance,
                priority: 10,
                title: 'Tu dinero',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tu dinero'), findsOneWidget);
    expect(find.text(r'$1,234.56'), findsOneWidget);
    expect(find.text('Cuenta principal · \$1,234.56'), findsOneWidget);
    expect(find.text('Ver mis cuentas'), findsOneWidget);
  });
}