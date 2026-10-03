import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neobank_core/neobank_core.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/storage/token_store.dart';

/// Acceso a los endpoints de autenticación y gestión de tokens.
class AuthRepository {
  AuthRepository(this._client, this._tokens);

  final ApiClient _client;
  final TokenStore _tokens;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final data = await _client.postJson(
      ApiPaths.login,
      body: {'email': email, 'password': password},
    );
    return _persist(AuthSession.fromJson(data));
  }

  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
    String? phone,
    String segment = 'standard',
  }) async {
    final data = await _client.postJson(
      ApiPaths.register,
      body: {
        'name': name,
        'email': email,
        'password': password,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'segment': segment,
      },
    );
    return _persist(AuthSession.fromJson(data));
  }

  Future<OtpChallenge> requestOtp(String email) async {
    final data = await _client.postJson(
      ApiPaths.otpRequest,
      body: {'email': email},
    );
    return OtpChallenge.fromJson(data);
  }

  Future<AuthSession> verifyOtp({
    required String challengeId,
    required String code,
  }) async {
    final data = await _client.postJson(
      ApiPaths.otpVerify,
      body: {'challengeId': challengeId, 'code': code},
    );
    return _persist(AuthSession.fromJson(data));
  }

  /// Devuelve el usuario si la sesión guardada sigue siendo válida.
  Future<User?> currentUser() async {
    final tokens = await _tokens.read();
    if (tokens == null) return null;
    final result = await _client.getJson(ApiPaths.me);
    return User.fromJson(result.data);
  }

  Future<void> logout() async {
    try {
      await _client.postVoid(ApiPaths.logout);
    } catch (_) {
      // El logout local siempre debe completarse.
    }
    await _tokens.clear();
  }

  Future<AuthSession> _persist(AuthSession session) async {
    await _tokens.write(session.tokens);
    return session;
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),
  ),
);
