import 'dart:math';

import 'package:neobank_core/neobank_core.dart';
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';

import '../../app.dart';
import '../../domain/errors.dart';
import '../http_helpers.dart';
import '../middleware.dart';

final RegExp _emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

/// Onboarding y autenticación (registro, login, refresh, OTP).
class AuthHandler {
  const AuthHandler(this.app);

  final AppContainer app;

  Future<Response> register(Request request) async {
    final body = await readJson(request);
    final name = (body['name'] as String?)?.trim() ?? '';
    final email = (body['email'] as String?)?.trim().toLowerCase() ?? '';
    final password = body['password'] as String? ?? '';

    if (name.length < 3) {
      throw ApiException.badRequest('El nombre debe tener al menos 3 caracteres');
    }
    if (!_emailRegex.hasMatch(email)) {
      throw ApiException.badRequest('Email inválido');
    }
    if (password.length < 8) {
      throw ApiException.badRequest('La contraseña debe tener al menos 8 caracteres');
    }
    if (app.store.findUserByEmail(email) != null) {
      throw ApiException.conflict('El email ya está registrado');
    }

    final record = app.store.insertUser(
      id: const Uuid().v4(),
      name: name,
      email: email,
      passwordHash: app.hasher.hash(password),
      segment: _parseSegment(body['segment']),
      phone: body['phone']?.toString(),
      documentId: body['documentId']?.toString(),
    );
    _provisionDefaultAccount(record.user);
    return jsonResponse(_issueSession(record.user).toJson(), status: 201);
  }

  Future<Response> login(Request request) async {
    final body = await readJson(request);
    final email = (body['email'] as String?)?.trim().toLowerCase() ?? '';
    final password = body['password'] as String? ?? '';
    final record = app.store.findUserByEmail(email);
    if (record == null || !app.hasher.verify(password, record.passwordHash)) {
      throw ApiException.unauthorized('Credenciales inválidas');
    }
    return jsonResponse(_issueSession(record.user).toJson());
  }

  Future<Response> refresh(Request request) async {
    final body = await readJson(request);
    final token = body['refreshToken'] as String? ?? '';
    final hash = app.tokens.hashRefreshToken(token);
    final existing = app.store.findRefreshToken(hash);
    if (existing == null || existing.revoked || existing.expiresAt.isBefore(DateTime.now())) {
      throw ApiException.unauthorized('Refresh token inválido o expirado');
    }
    final record = app.store.findUserById(existing.userId);
    if (record == null) {
      throw ApiException.unauthorized('Usuario no encontrado');
    }
    app.store.revokeRefreshToken(hash); // rotación de refresh token
    return jsonResponse(_issueSession(record.user).toJson());
  }

  Future<Response> logout(Request request) async {
    final user = currentUser(request);
    final body = await readJson(request);
    final token = body['refreshToken'] as String?;
    if (token != null && token.isNotEmpty) {
      app.store.revokeRefreshToken(app.tokens.hashRefreshToken(token));
    } else {
      app.store.revokeAllRefreshTokens(user.id);
    }
    return noContent();
  }

  Future<Response> requestOtp(Request request) async {
    final body = await readJson(request);
    final email = (body['email'] as String?)?.trim().toLowerCase() ?? '';
    final record = app.store.findUserByEmail(email);
    if (record == null) {
      throw ApiException.notFound('Usuario no encontrado');
    }
    final code = (100000 + Random.secure().nextInt(900000)).toString();
    final challengeId = const Uuid().v4();
    app.store.saveOtpChallenge(
      id: challengeId,
      userId: record.user.id,
      codeHash: app.tokens.hashRefreshToken(code),
      expiresAt: DateTime.now().toUtc().add(app.config.otpTtl),
    );
    return jsonResponse(
      OtpChallenge(
        challengeId: challengeId,
        expiresIn: app.config.otpTtl.inSeconds,
        devCode: app.config.isDevelopment ? code : null,
      ).toJson(),
      status: 202,
    );
  }

  Future<Response> verifyOtp(Request request) async {
    final body = await readJson(request);
    final challengeId = body['challengeId'] as String? ?? '';
    final code = body['code'] as String? ?? '';
    final challenge = app.store.findOtp(challengeId);
    if (challenge == null) {
      throw ApiException.badRequest('Reto OTP inexistente');
    }
    if (challenge.consumed || challenge.expiresAt.isBefore(DateTime.now())) {
      throw ApiException.badRequest('Código expirado o ya usado');
    }
    app.store.incrementOtpAttempts(challengeId);
    if (challenge.attempts >= 5) {
      throw ApiException.forbidden('Demasiados intentos');
    }
    if (app.tokens.hashRefreshToken(code) != challenge.codeHash) {
      throw ApiException.unauthorized('Código inválido');
    }
    app.store.consumeOtp(challengeId);
    final record = app.store.findUserById(challenge.userId);
    if (record == null) {
      throw ApiException.unauthorized('Usuario no encontrado');
    }
    return jsonResponse(_issueSession(record.user).toJson());
  }

  Future<Response> me(Request request) async {
    final user = currentUser(request);
    return jsonResponse(user.toJson());
  }

  AuthSession _issueSession(User user) {
    final accessToken = app.tokens.issueAccessToken(user.id);
    final refreshToken = app.tokens.generateRefreshToken();
    app.store.saveRefreshToken(
      id: const Uuid().v4(),
      userId: user.id,
      tokenHash: app.tokens.hashRefreshToken(refreshToken),
      expiresAt: app.tokens.refreshExpiry(),
    );
    return AuthSession(
      user: user,
      tokens: AuthTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresIn: app.config.accessTokenTtl.inSeconds,
      ),
    );
  }

  /// Crea la cuenta base y un bono de bienvenida para usuarios nuevos.
  void _provisionDefaultAccount(User user) {
    final suffix = (1000 + Random.secure().nextInt(9000)).toString();
    app.store.insertAccount(
      id: 'acc_${const Uuid().v4()}',
      userId: user.id,
      type: AccountType.checking,
      alias: 'Cuenta principal',
      numberMasked: '**** $suffix',
      currency: 'USD',
      balanceMinor: 0,
      availableMinor: 0,
    );
    final accounts = app.store.accountsForUser(user.id);
    if (accounts.isEmpty) return;
    app.store.applyTransaction(
      accountId: accounts.first.id,
      type: TransactionType.credit,
      category: 'welcome',
      description: 'Bono de bienvenida',
      amountMinor: 5000,
      currency: 'USD',
      merchant: 'Neobank',
    );
  }

  UserSegment _parseSegment(Object? value) {
    if (value is! String) return UserSegment.standard;
    return UserSegment.values.firstWhere(
      (segment) => segment.name == value,
      orElse: () => UserSegment.standard,
    );
  }
}
