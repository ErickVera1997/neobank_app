import 'package:neobank_core/neobank_core.dart';

import '../security/password_hasher.dart';
import 'store.dart';

/// Datos de demostración reproducibles (usuario, cuentas, movimientos,
/// notificaciones y feature flags). Idempotente: no duplica si ya existe.
class SeedData {
  const SeedData(this._store, this._hasher);

  final Store _store;
  final PasswordHasher _hasher;

  static const String demoEmail = 'ana@neobank.com';
  static const String demoPassword = 'Password123';

  void ensure() {
    if (_store.findUserByEmail(demoEmail) != null) return;
    _seedUser();
    _seedFlags();
  }

  void _seedUser() {
    const userId = 'u_demo';
    _store.insertUser(
      id: userId,
      name: 'Ana Torres',
      email: demoEmail,
      passwordHash: _hasher.hash(demoPassword),
      segment: UserSegment.premium,
      phone: '+593 99 123 4567',
      documentId: '1712345678',
      onboardingCompleted: true,
    );

    _store.insertAccount(
      id: 'acc_savings',
      userId: userId,
      type: AccountType.savings,
      alias: 'Ahorros viaje',
      numberMasked: '**** 4821',
      currency: 'USD',
      balanceMinor: 0,
      availableMinor: 0,
    );
    _store.insertAccount(
      id: 'acc_checking',
      userId: userId,
      type: AccountType.checking,
      alias: 'Cuenta principal',
      numberMasked: '**** 1190',
      currency: 'USD',
      balanceMinor: 0,
      availableMinor: 0,
    );
    _store.insertAccount(
      id: 'acc_investment',
      userId: userId,
      type: AccountType.investment,
      alias: 'Portafolio conservador',
      numberMasked: '**** 7734',
      currency: 'USD',
      balanceMinor: 0,
      availableMinor: 0,
    );
    _store.insertAccount(
      id: 'acc_credit',
      userId: userId,
      type: AccountType.credit,
      alias: 'Tarjeta Platinum',
      numberMasked: '**** 5502',
      currency: 'USD',
      balanceMinor: 0,
      availableMinor: 0,
      creditLimitMinor: 5000000,
    );

    _seedChecking(userId);
    _seedSavings(userId);
    _seedInvestment(userId);
    _seedCredit(userId);
    _seedNotifications(userId);
  }

  void _seedChecking(String userId) {
    // Saldo inicial y luego movimientos reales aplicados de forma atómica.
    _setBalance('acc_checking', 1280000);
    final movements = <_SeedMovement>[
      _SeedMovement(45, TransactionType.credit, 'salary', 'Nómina mensual', 3200000, 'ACME Corp'),
      _SeedMovement(44, TransactionType.debit, 'housing', 'Arriendo', -980000, 'Inmobiliaria Andina'),
      _SeedMovement(42, TransactionType.debit, 'groceries', 'Supermercado', -84250, 'Supermaxi'),
      _SeedMovement(40, TransactionType.debit, 'transport', 'Combustible', -45000, 'Primax'),
      _SeedMovement(38, TransactionType.debit, 'dining', 'Cena', -32900, 'La Trattoria'),
      _SeedMovement(35, TransactionType.debit, 'utilities', 'Plan de datos', -28999, 'Claro'),
      _SeedMovement(33, TransactionType.credit, 'transfer', 'Transferencia recibida', 150000, 'Diego M.'),
      _SeedMovement(30, TransactionType.debit, 'entertainment', 'Streaming', -1599, 'Netflix'),
      _SeedMovement(28, TransactionType.debit, 'groceries', 'Supermercado', -96870, 'Supermaxi'),
      _SeedMovement(25, TransactionType.debit, 'health', 'Farmacia', -22150, 'Fybeca'),
      _SeedMovement(22, TransactionType.credit, 'freelance', 'Proyecto freelance', 800000, 'Studio Nine'),
      _SeedMovement(20, TransactionType.debit, 'shopping', 'Ropa', -139900, 'Zara'),
      _SeedMovement(18, TransactionType.debit, 'transport', 'Taxi', -12600, 'Uber'),
      _SeedMovement(15, TransactionType.debit, 'utilities', 'Energía eléctrica', -61200, 'EEQ'),
      _SeedMovement(12, TransactionType.debit, 'groceries', 'Supermercado', -73840, 'Supermaxi'),
      _SeedMovement(10, TransactionType.credit, 'cashback', 'Cashback tarjeta', 12400, 'Neobank'),
      _SeedMovement(8, TransactionType.debit, 'dining', 'Café', -8900, 'Juan Valdez'),
      _SeedMovement(6, TransactionType.debit, 'transfer', 'Transferencia a ahorros', -250000, 'Ahorros viaje'),
      _SeedMovement(4, TransactionType.debit, 'transport', 'Taxi', -9800, 'Uber'),
      _SeedMovement(2, TransactionType.debit, 'groceries', 'Supermercado', -65120, 'Supermaxi'),
      _SeedMovement(1, TransactionType.debit, 'entertainment', 'Cine', -18000, 'Cinemark'),
    ];
    for (final movement in movements) {
      _apply('acc_checking', movement);
    }
  }

  void _seedSavings(String userId) {
    _setBalance('acc_savings', 300000);
    _apply(
      'acc_savings',
      _SeedMovement(6, TransactionType.credit, 'transfer', 'Desde cuenta principal', 250000, 'Cuenta principal'),
    );
    _apply(
      'acc_savings',
      _SeedMovement(3, TransactionType.credit, 'interest', 'Interés mensual', 18700, 'Neobank'),
    );
  }

  void _seedInvestment(String userId) {
    _setBalance('acc_investment', 700000);
    _apply(
      'acc_investment',
      _SeedMovement(30, TransactionType.credit, 'contribution', 'Aporte mensual', 100000, 'Cuenta principal'),
    );
    _apply(
      'acc_investment',
      _SeedMovement(7, TransactionType.credit, 'yield', 'Rendimiento', 24300, 'Neobank'),
    );
  }

  void _seedCredit(String userId) {
    _setBalance('acc_credit', 0);
    _apply('acc_credit', _SeedMovement(20, TransactionType.debit, 'shopping', 'Compra Zara', 139900, 'Zara'));
    _apply('acc_credit', _SeedMovement(9, TransactionType.debit, 'dining', 'Cena', 45200, 'La Trattoria'));
    _apply('acc_credit', _SeedMovement(5, TransactionType.credit, 'payment', 'Pago tarjeta', 100000, 'Cuenta principal'));
  }

  void _seedNotifications(String userId) {
    _store.insertNotification(
      id: 'notif_welcome',
      userId: userId,
      title: '¡Bienvenida a Neobank!',
      body: 'Tu cuenta está lista. Configura tus metas y alertas.',
      type: AppNotificationType.system,
      createdAt: DateTime.now().toUtc().subtract(const Duration(days: 2)),
    );
    _store.insertNotification(
      id: 'notif_salary',
      userId: userId,
      title: 'Recibiste un abono',
      body: '+USD 32,000.00 · Nómina mensual',
      type: AppNotificationType.transaction,
      data: {'accountId': 'acc_checking'},
      createdAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
    );
  }

  void _seedFlags() {
    const all = [
      UserSegment.youth,
      UserSegment.standard,
      UserSegment.premium,
      UserSegment.pyme,
    ];
    _store.upsertFlag(
      key: 'fx_widget',
      enabled: true,
      variant: 'v2',
      payload: const {'defaultFrom': 'USD', 'defaultTo': 'EUR'},
      segments: all,
    );
    _store.upsertFlag(
      key: 'offers_carousel',
      enabled: true,
      segments: all,
    );
    _store.upsertFlag(
      key: 'insights',
      enabled: true,
      segments: all,
    );
    _store.upsertFlag(
      key: 'investments_module',
      enabled: true,
      payload: const {'riskProfile': 'conservative'},
      segments: const [UserSegment.standard, UserSegment.premium, UserSegment.pyme],
    );
    _store.upsertFlag(
      key: 'early_salary',
      enabled: true,
      variant: 'treatment',
      payload: const {'maxAdvanceMinor': 500000},
      segments: const [UserSegment.premium],
    );
    _store.upsertFlag(
      key: 'card_controls',
      enabled: true,
      segments: const [UserSegment.standard, UserSegment.premium, UserSegment.pyme],
    );
    _store.upsertFlag(
      key: 'beta_crypto',
      enabled: false,
      variant: 'control',
      segments: all,
    );
    _store.upsertFlag(
      key: 'assistant',
      enabled: true,
      payload: const {
        'examples': [
          '¿Cuál es mi saldo?',
          '¿Cuánto gasté este mes?',
          '¿Cuánto es 100 USD en EUR?',
        ],
      },
      segments: all,
    );
  }

  void _setBalance(String accountId, int minor) {
    _store.setAccountBalance(
      accountId,
      balanceMinor: minor,
      availableMinor: minor,
    );
  }

  void _apply(String accountId, _SeedMovement movement) {
    _store.applyTransaction(
      accountId: accountId,
      type: movement.type,
      category: movement.category,
      description: movement.description,
      amountMinor: movement.amountMinor.abs(),
      currency: 'USD',
      merchant: movement.merchant,
      createdAt: DateTime.now().toUtc().subtract(Duration(days: movement.daysAgo)),
    );
  }
}

class _SeedMovement {
  const _SeedMovement(
    this.daysAgo,
    this.type,
    this.category,
    this.description,
    this.amountMinor,
    this.merchant,
  );

  final int daysAgo;
  final TransactionType type;
  final String category;
  final String description;
  final int amountMinor;
  final String? merchant;
}
