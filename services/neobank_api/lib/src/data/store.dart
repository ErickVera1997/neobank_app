import 'dart:convert';

import 'package:neobank_core/neobank_core.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import 'database.dart';

/// Registro de usuario con su hash de contraseña (nunca sale del backend).
class UserRecord {
  const UserRecord({required this.user, required this.passwordHash});

  final User user;
  final String passwordHash;
}

/// Repositorio central sobre SQLite. Agrupa las consultas de todos los
/// agregados para mantener el acceso a datos en un único lugar.
class Store {
  Store(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  // ───────────────────────────────────────────────────────────── Usuarios

  UserRecord insertUser({
    required String id,
    required String name,
    required String email,
    required String passwordHash,
    required UserSegment segment,
    String? phone,
    String? documentId,
    bool onboardingCompleted = false,
  }) {
    final createdAt = DateTime.now().toUtc();
    _db.execute(
      'INSERT INTO users (id, name, email, phone, document_id, password_hash, '
      'segment, onboarding_completed, created_at) VALUES (?,?,?,?,?,?,?,?,?)',
      [
        id,
        name,
        email.toLowerCase(),
        phone,
        documentId,
        passwordHash,
        segment.name,
        onboardingCompleted ? 1 : 0,
        createdAt.toIso8601String(),
      ],
    );
    return UserRecord(
      user: User(
        id: id,
        name: name,
        email: email.toLowerCase(),
        segment: segment,
        createdAt: createdAt,
        phone: phone,
        documentId: documentId,
        onboardingCompleted: onboardingCompleted,
      ),
      passwordHash: passwordHash,
    );
  }

  UserRecord? findUserByEmail(String email) {
    final rows = _db.select(
      'SELECT * FROM users WHERE email = ?',
      [email.toLowerCase()],
    );
    return rows.isEmpty ? null : _userFromRow(rows.first);
  }

  UserRecord? findUserById(String id) {
    final rows = _db.select('SELECT * FROM users WHERE id = ?', [id]);
    return rows.isEmpty ? null : _userFromRow(rows.first);
  }

  void updateUserProfile(
    String userId, {
    String? name,
    String? phone,
    String? avatarUrl,
    bool? onboardingCompleted,
  }) {
    final sets = <String>[];
    final args = <Object?>[];
    if (name != null) {
      sets.add('name = ?');
      args.add(name);
    }
    if (phone != null) {
      sets.add('phone = ?');
      args.add(phone);
    }
    if (avatarUrl != null) {
      sets.add('avatar_url = ?');
      args.add(avatarUrl);
    }
    if (onboardingCompleted != null) {
      sets.add('onboarding_completed = ?');
      args.add(onboardingCompleted ? 1 : 0);
    }
    if (sets.isEmpty) return;
    args.add(userId);
    _db.execute('UPDATE users SET ${sets.join(', ')} WHERE id = ?', args);
  }

  UserRecord _userFromRow(Row row) => UserRecord(
        user: User(
          id: row['id'] as String,
          name: row['name'] as String,
          email: row['email'] as String,
          segment: UserSegment.fromName(row['segment'] as String?),
          createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
          phone: row['phone'] as String?,
          documentId: row['document_id'] as String?,
          avatarUrl: row['avatar_url'] as String?,
          onboardingCompleted: (row['onboarding_completed'] as int) == 1,
        ),
        passwordHash: row['password_hash'] as String,
      );

  // ──────────────────────────────────────────────── Refresh / OTP

  void saveRefreshToken({
    required String id,
    required String userId,
    required String tokenHash,
    required DateTime expiresAt,
  }) {
    _db.execute(
      'INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at, '
      'created_at) VALUES (?,?,?,?,?)',
      [
        id,
        userId,
        tokenHash,
        expiresAt.toIso8601String(),
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
  }

  ({String userId, bool revoked, DateTime expiresAt})? findRefreshToken(
    String tokenHash,
  ) {
    final rows = _db.select(
      'SELECT * FROM refresh_tokens WHERE token_hash = ?',
      [tokenHash],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return (
      userId: row['user_id'] as String,
      revoked: (row['revoked'] as int) == 1,
      expiresAt: DateTime.parse(row['expires_at'] as String),
    );
  }

  void revokeRefreshToken(String tokenHash) => _db.execute(
        'UPDATE refresh_tokens SET revoked = 1 WHERE token_hash = ?',
        [tokenHash],
      );

  void revokeAllRefreshTokens(String userId) => _db.execute(
        'UPDATE refresh_tokens SET revoked = 1 WHERE user_id = ?',
        [userId],
      );

  void saveOtpChallenge({
    required String id,
    required String userId,
    required String codeHash,
    required DateTime expiresAt,
  }) {
    _db.execute(
      'INSERT INTO otp_challenges (id, user_id, code_hash, expires_at, '
      'created_at) VALUES (?,?,?,?,?)',
      [
        id,
        userId,
        codeHash,
        expiresAt.toIso8601String(),
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
  }

  ({String userId, String codeHash, DateTime expiresAt, bool consumed, int attempts})?
      findOtp(String id) {
    final rows = _db.select(
      'SELECT * FROM otp_challenges WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return (
      userId: row['user_id'] as String,
      codeHash: row['code_hash'] as String,
      expiresAt: DateTime.parse(row['expires_at'] as String),
      consumed: (row['consumed'] as int) == 1,
      attempts: row['attempts'] as int,
    );
  }

  void consumeOtp(String id) =>
      _db.execute('UPDATE otp_challenges SET consumed = 1 WHERE id = ?', [id]);

  void incrementOtpAttempts(String id) => _db.execute(
        'UPDATE otp_challenges SET attempts = attempts + 1 WHERE id = ?',
        [id],
      );

  // ───────────────────────────────────────────────────────────── Cuentas

  void insertAccount({
    required String id,
    required String userId,
    required AccountType type,
    required String alias,
    required String numberMasked,
    required String currency,
    required int balanceMinor,
    required int availableMinor,
    int? creditLimitMinor,
    AccountStatus status = AccountStatus.active,
  }) {
    _db.execute(
      'INSERT INTO accounts (id, user_id, type, alias, number_masked, currency, '
      'balance_minor, available_minor, credit_limit_minor, status, created_at) '
      'VALUES (?,?,?,?,?,?,?,?,?,?,?)',
      [
        id,
        userId,
        type.name,
        alias,
        numberMasked,
        currency,
        balanceMinor,
        availableMinor,
        creditLimitMinor,
        status.name,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
  }

  List<BankAccount> accountsForUser(String userId) {
    final rows = _db.select(
      'SELECT * FROM accounts WHERE user_id = ? ORDER BY created_at ASC',
      [userId],
    );
    return rows.map(_accountFromRow).toList(growable: false);
  }

  BankAccount? accountById(String id) {
    final rows = _db.select('SELECT * FROM accounts WHERE id = ?', [id]);
    return rows.isEmpty ? null : _accountFromRow(rows.first);
  }

  /// Ajuste directo de saldo (usado por datos semilla / procesos batch).
  void setAccountBalance(
    String accountId, {
    required int balanceMinor,
    required int availableMinor,
  }) {
    _db.execute(
      'UPDATE accounts SET balance_minor = ?, available_minor = ? WHERE id = ?',
      [balanceMinor, availableMinor, accountId],
    );
  }

  BankAccount _accountFromRow(Row row) => BankAccount(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        type: AccountType.fromName(row['type'] as String?),
        alias: row['alias'] as String,
        numberMasked: row['number_masked'] as String,
        currency: row['currency'] as String,
        balance: Money(row['balance_minor'] as int, row['currency'] as String),
        available:
            Money(row['available_minor'] as int, row['currency'] as String),
        status: AccountStatus.fromName(row['status'] as String?),
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
        creditLimit: row['credit_limit_minor'] == null
            ? null
            : Money(row['credit_limit_minor'] as int, row['currency'] as String),
      );

  // ─────────────────────────────────────────────────────── Movimientos

  void insertTransaction({
    required String id,
    required String accountId,
    required TransactionType type,
    required String category,
    required String description,
    required int amountMinor,
    required String currency,
    required int balanceAfterMinor,
    TransactionStatus status = TransactionStatus.posted,
    String? merchant,
    DateTime? createdAt,
  }) {
    _db.execute(
      'INSERT INTO transactions (id, account_id, type, category, description, '
      'amount_minor, currency, balance_after_minor, status, merchant, created_at) '
      'VALUES (?,?,?,?,?,?,?,?,?,?,?)',
      [
        id,
        accountId,
        type.name,
        category,
        description,
        amountMinor,
        currency,
        balanceAfterMinor,
        status.name,
        merchant,
        (createdAt ?? DateTime.now().toUtc()).toUtc().toIso8601String(),
      ],
    );
  }

  /// Actualiza el saldo de una cuenta de forma atómica y registra el movimiento.
  BankTransaction applyTransaction({
    required String accountId,
    required TransactionType type,
    required String category,
    required String description,
    required int amountMinor,
    required String currency,
    String? merchant,
    TransactionStatus status = TransactionStatus.posted,
    String? transactionId,
    DateTime? createdAt,
  }) {
    final account = accountById(accountId);
    if (account == null) {
      throw StateError('Cuenta no encontrada: $accountId');
    }
    final signed = type == TransactionType.credit ? amountMinor : -amountMinor;
    final newBalance = account.balance.minorUnits + signed;
    final newAvailable = account.available.minorUnits + signed;
    final id = transactionId ?? const Uuid().v4();
    final effectiveCreatedAt = createdAt ?? DateTime.now();
    final tx = BankTransaction(
      id: id,
      accountId: accountId,
      type: type,
      category: category,
      description: description,
      amount: Money(signed, currency),
      balanceAfter: Money(newBalance, currency),
      status: status,
      createdAt: effectiveCreatedAt,
      merchant: merchant,
    );
    _db.execute('BEGIN IMMEDIATE;');
    try {
      insertTransaction(
        id: tx.id,
        accountId: accountId,
        type: type,
        category: category,
        description: description,
        amountMinor: signed,
        currency: currency,
        balanceAfterMinor: newBalance,
        status: status,
        merchant: merchant,
        createdAt: effectiveCreatedAt,
      );
      _db.execute(
        'UPDATE accounts SET balance_minor = ?, available_minor = ? WHERE id = ?',
        [newBalance, newAvailable, accountId],
      );
      _db.execute('COMMIT;');
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
    return tx;
  }

  /// Movimientos de todas las cuentas de un usuario en un rango de fechas.
  List<BankTransaction> transactionsForUser(
    String userId, {
    DateTime? from,
    DateTime? to,
    int limit = 500,
  }) {
    final accountIds =
        accountsForUser(userId).map((account) => account.id).toList();
    if (accountIds.isEmpty) return const [];
    final placeholders = List.filled(accountIds.length, '?').join(',');
    final args = <Object?>[...accountIds];
    var sql =
        'SELECT * FROM transactions WHERE account_id IN ($placeholders)';
    if (from != null) {
      sql += ' AND created_at >= ?';
      args.add(from.toUtc().toIso8601String());
    }
    if (to != null) {
      sql += ' AND created_at < ?';
      args.add(to.toUtc().toIso8601String());
    }
    sql += ' ORDER BY created_at DESC, id DESC LIMIT ?';
    args.add(limit);
    final rows = _db.select(sql, args);
    return rows.map(_transactionFromRow).toList(growable: false);
  }

  /// Página de movimientos con paginación por cursor.
  TransactionPage transactionsForAccount(
    String accountId, {
    String? cursor,
    int limit = 20,
  }) {
    late final ResultSet rows;
    if (cursor == null || cursor.isEmpty) {
      rows = _db.select(
        'SELECT * FROM transactions WHERE account_id = ? '
        'ORDER BY created_at DESC, id DESC LIMIT ?',
        [accountId, limit + 1],
      );
    } else {
      final decoded = _decodeCursor(cursor);
      rows = _db.select(
        'SELECT * FROM transactions WHERE account_id = ? AND '
        '(created_at < ? OR (created_at = ? AND id < ?)) '
        'ORDER BY created_at DESC, id DESC LIMIT ?',
        [accountId, decoded.createdAt, decoded.createdAt, decoded.id, limit + 1],
      );
    }
    final hasMore = rows.length > limit;
    final pageRows = rows.take(limit).toList(growable: false);
    final items = pageRows.map(_transactionFromRow).toList(growable: false);
    String? nextCursor;
    if (hasMore && pageRows.isNotEmpty) {
      final last = pageRows.last;
      nextCursor = _encodeCursor(
        last['created_at'] as String,
        last['id'] as String,
      );
    }
    return TransactionPage(items: items, nextCursor: nextCursor);
  }

  BankTransaction _transactionFromRow(Row row) => BankTransaction(
        id: row['id'] as String,
        accountId: row['account_id'] as String,
        type: TransactionType.fromName(row['type'] as String?),
        category: row['category'] as String,
        description: row['description'] as String,
        amount: Money(row['amount_minor'] as int, row['currency'] as String),
        balanceAfter:
            Money(row['balance_after_minor'] as int, row['currency'] as String),
        status: TransactionStatus.fromName(row['status'] as String?),
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
        merchant: row['merchant'] as String?,
      );

  String _encodeCursor(String createdAt, String id) =>
      base64Url.encode(utf8.encode('$createdAt|$id'));

  ({String createdAt, String id}) _decodeCursor(String cursor) {
    final parts = utf8.decode(base64Url.decode(cursor)).split('|');
    return (createdAt: parts.first, id: parts.last);
  }

  // ─────────────────────────────────────────────────────────── Dispositivos

  void upsertDeviceToken({
    required String id,
    required String userId,
    required String token,
    required String platform,
  }) {
    _db.execute(
      'INSERT INTO device_tokens (id, user_id, token, platform, created_at) '
      'VALUES (?,?,?,?,?) '
      'ON CONFLICT(user_id, token) DO UPDATE SET platform = excluded.platform',
      [
        id,
        userId,
        token,
        platform,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
  }

  List<String> deviceTokensForUser(String userId) {
    final rows = _db.select(
      'SELECT token FROM device_tokens WHERE user_id = ?',
      [userId],
    );
    return rows.map((row) => row['token'] as String).toList(growable: false);
  }

  // ──────────────────────────────────────────────────────── Notificaciones

  void insertNotification({
    required String id,
    required String userId,
    required String title,
    required String body,
    required AppNotificationType type,
    Map<String, dynamic> data = const {},
    DateTime? createdAt,
  }) {
    _db.execute(
      'INSERT INTO notifications (id, user_id, title, body, type, read, '
      'data_json, created_at) VALUES (?,?,?,?,?,0,?,?)',
      [
        id,
        userId,
        title,
        body,
        type.name,
        jsonEncode(data),
        (createdAt ?? DateTime.now().toUtc()).toUtc().toIso8601String(),
      ],
    );
  }

  List<AppNotification> notificationsForUser(String userId, {int limit = 50}) {
    final rows = _db.select(
      'SELECT * FROM notifications WHERE user_id = ? '
      'ORDER BY created_at DESC LIMIT ?',
      [userId, limit],
    );
    return rows.map(_notificationFromRow).toList(growable: false);
  }

  int unreadNotificationCount(String userId) {
    final rows = _db.select(
      'SELECT COUNT(*) AS c FROM notifications WHERE user_id = ? AND read = 0',
      [userId],
    );
    return rows.first['c'] as int;
  }

  bool markNotificationRead(String id, String userId) {
    final existing = _db.select(
      'SELECT id FROM notifications WHERE id = ? AND user_id = ?',
      [id, userId],
    );
    if (existing.isEmpty) return false;
    _db.execute('UPDATE notifications SET read = 1 WHERE id = ?', [id]);
    return true;
  }

  AppNotification _notificationFromRow(Row row) => AppNotification(
        id: row['id'] as String,
        title: row['title'] as String,
        body: row['body'] as String,
        type: AppNotificationType.fromName(row['type'] as String?),
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
        read: (row['read'] as int) == 1,
        data: (jsonDecode(row['data_json'] as String) as Map)
            .cast<String, dynamic>(),
      );

  // ────────────────────────────────────────────────────────────── FX

  void saveFxCache({
    required String base,
    required Map<String, double> rates,
    required String source,
    required DateTime fetchedAt,
  }) {
    _db.execute(
      'INSERT INTO fx_cache (base, rates_json, source, fetched_at) '
      'VALUES (?,?,?,?) '
      'ON CONFLICT(base) DO UPDATE SET rates_json = excluded.rates_json, '
      'source = excluded.source, fetched_at = excluded.fetched_at',
      [base, jsonEncode(rates), source, fetchedAt.toUtc().toIso8601String()],
    );
  }

  FxRates? getFxCache(String base) {
    final rows = _db.select('SELECT * FROM fx_cache WHERE base = ?', [base]);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return FxRates(
      base: row['base'] as String,
      rates: (jsonDecode(row['rates_json'] as String) as Map)
          .map((key, value) => MapEntry(key as String, (value as num).toDouble())),
      source: row['source'] as String,
      fetchedAt: DateTime.parse(row['fetched_at'] as String).toLocal(),
      stale: true,
    );
  }

  // ───────────────────────────────────────────────────── Feature flags

  void upsertFlag({
    required String key,
    required bool enabled,
    String? variant,
    Map<String, dynamic> payload = const {},
    List<UserSegment> segments = const [UserSegment.youth, UserSegment.standard, UserSegment.premium, UserSegment.pyme],
  }) {
    _db.execute(
      'INSERT INTO feature_flags (key, enabled, variant, payload_json, segments) '
      'VALUES (?,?,?,?,?) '
      'ON CONFLICT(key) DO UPDATE SET enabled = excluded.enabled, '
      'variant = excluded.variant, payload_json = excluded.payload_json, '
      'segments = excluded.segments',
      [
        key,
        enabled ? 1 : 0,
        variant,
        jsonEncode(payload),
        jsonEncode(segments.map((s) => s.name).toList()),
      ],
    );
  }

  List<FeatureFlag> flagsForSegment(UserSegment segment) {
    final rows = _db.select('SELECT * FROM feature_flags');
    final flags = <FeatureFlag>[];
    for (final row in rows) {
      final segments = (jsonDecode(row['segments'] as String) as List)
          .map((value) => value.toString())
          .toList();
      if (!segments.contains(segment.name)) continue;
      flags.add(
        FeatureFlag(
          key: row['key'] as String,
          enabled: (row['enabled'] as int) == 1,
          variant: row['variant'] as String?,
          payload: (jsonDecode(row['payload_json'] as String) as Map)
              .cast<String, dynamic>(),
        ),
      );
    }
    return flags;
  }
}
