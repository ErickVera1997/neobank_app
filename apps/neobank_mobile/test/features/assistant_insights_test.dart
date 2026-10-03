import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neobank_core/neobank_core.dart';
import 'package:neobank_mobile/src/features/assistant/data/assistant_repository.dart';
import 'package:neobank_mobile/src/features/insights/data/insights_repository.dart';
import 'package:neobank_mobile/src/features/insights/presentation/insights_screen.dart';

class _FakeAssistantRepository implements AssistantRepository {
  @override
  Future<AssistantAnswer> ask(String message) async => AssistantAnswer(
        reply: r'Tu saldo total es $10.00',
        intent: 'balance',
        suggestions: const ['¿Cuánto gasté este mes?'],
        card: const AssistantCard(
          type: 'balance',
          title: 'Saldo consolidado',
          amount: Money(1000, 'USD'),
        ),
      );
}

SpendingInsights _insights() => SpendingInsights(
      periodStart: DateTime(2026, 10),
      periodEnd: DateTime(2026, 11),
      income: const Money(320000, 'USD'),
      expenses: const Money(83120, 'USD'),
      net: const Money(236880, 'USD'),
      currency: 'USD',
      byCategory: const [
        CategorySpend(
          category: 'groceries',
          amount: Money(65120, 'USD'),
          share: 0.78,
          transactions: 2,
        ),
      ],
      topMerchants: const [
        MerchantSpend(merchant: 'Supermaxi', amount: Money(65120, 'USD')),
      ],
      savingsRate: 0.74,
      changeVsPrevious: -0.12,
      transactionCount: 12,
      messages: const [
        InsightMessage(
          id: 'top_category',
          title: 'Tu mayor gasto: supermercado',
          body: r'$651.20 este mes.',
          tone: 'neutral',
        ),
      ],
      generatedAt: DateTime(2026, 10, 3),
    );

void main() {
  test('AssistantController agrega la pregunta y la respuesta', () async {
    final container = ProviderContainer(
      overrides: [
        assistantRepositoryProvider
            .overrideWithValue(_FakeAssistantRepository()),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(assistantControllerProvider).messages.length, 1);

    await container
        .read(assistantControllerProvider.notifier)
        .send('¿Cuál es mi saldo?');

    final thread = container.read(assistantControllerProvider);
    expect(thread.thinking, isFalse);
    expect(thread.messages.length, 3);
    expect(thread.messages[1].fromUser, isTrue);
    final answer = thread.messages.last.answer;
    expect(answer?.intent, 'balance');
    expect(answer?.card?.type, 'balance');
    expect(thread.messages.last.text, contains('Tu saldo total'));
  });

  testWidgets('InsightsScreen muestra la analítica generada', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          insightsProvider.overrideWith((ref) async => _insights()),
        ],
        child: const MaterialApp(home: InsightsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tu análisis'), findsOneWidget);
    expect(find.text('Descubrimientos'), findsOneWidget);
    expect(find.text('Tu mayor gasto: supermercado'), findsOneWidget);
    expect(find.text('Gasto por categoría'), findsOneWidget);
    expect(find.text('Supermercado'), findsOneWidget);

    // La sección de comercios está más abajo: hacemos scroll.
    await tester.scrollUntilVisible(find.text('Supermaxi'), 300);
    expect(find.text('Comercios frecuentes'), findsOneWidget);
    expect(find.text('Supermaxi'), findsOneWidget);
  });
}