import 'package:neobank_core/neobank_core.dart';
import 'package:test/test.dart';

void main() {
  group('AppBootstrap', () {
    test('deserializa flags, home modules y ofertas', () {
      final json = {
        'user': {
          'id': 'u1',
          'name': 'Ana',
          'email': 'ana@neobank.com',
          'segment': 'premium',
          'createdAt': '2026-01-01T10:00:00.000Z',
        },
        'version': '7',
        'experimentBucket': 'B',
        'theme': {'brandName': 'Neobank', 'seedColorHex': '#0F62FE'},
        'flags': [
          {'key': 'fx_widget', 'enabled': true},
          {'key': 'beta_crypto', 'enabled': false, 'variant': 'control'},
        ],
        'home': [
          {
            'id': 'hero',
            'type': 'heroBalance',
            'priority': 10,
            'config': {'showAvailable': true},
          },
        ],
        'offers': [
          {
            'id': 'o1',
            'title': 'Cashback',
            'description': '3% en restaurantes',
            'priority': 5,
          },
        ],
      };

      final bootstrap = AppBootstrap.fromJson(json);

      expect(bootstrap.user.segment, UserSegment.premium);
      expect(bootstrap.flagEnabled('fx_widget'), isTrue);
      expect(bootstrap.flagEnabled('beta_crypto'), isFalse);
      expect(bootstrap.flag('beta_crypto')?.variant, 'control');
      expect(bootstrap.home.single.type, HomeModuleType.heroBalance);
      expect(bootstrap.offers.single.title, 'Cashback');
      expect(bootstrap.theme.seedColorHex, '#0F62FE');
      expect(bootstrap.experimentBucket, 'B');
    });
  });

  group('BankTransaction', () {
    test('round-trip JSON', () {
      final tx = BankTransaction(
        id: 't1',
        accountId: 'a1',
        type: TransactionType.credit,
        category: 'salary',
        description: 'Nómina',
        amount: const Money(500000, 'USD'),
        balanceAfter: const Money(700000, 'USD'),
        status: TransactionStatus.posted,
        createdAt: DateTime.utc(2026, 2, 1, 12),
        merchant: 'ACME',
      );

      final restored = BankTransaction.fromJson(tx.toJson());
      expect(restored.id, tx.id);
      expect(restored.type, TransactionType.credit);
      expect(restored.amount, tx.amount);
      expect(restored.createdAt.toUtc(), tx.createdAt);
    });
  });
}
