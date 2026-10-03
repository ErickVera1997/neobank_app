import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// Emisión y verificación de tokens JWT (access) y refresh tokens opacos.
class TokenService {
  TokenService({
    required this.secret,
    required this.accessTokenTtl,
    required this.refreshTokenTtl,
  });

  final String secret;
  final Duration accessTokenTtl;
  final Duration refreshTokenTtl;

  String issueAccessToken(String userId) {
    final now = DateTime.now().toUtc();
    final jwt = JWT(
      {
        'sub': userId,
        'type': 'access',
        'iat': now.millisecondsSinceEpoch ~/ 1000,
      },
      issuer: 'neobank',
    );
    return jwt.sign(
      SecretKey(secret),
      expiresIn: accessTokenTtl,
      algorithm: JWTAlgorithm.HS256,
    );
  }

  /// Devuelve el `userId` (`sub`) o `null` si el token es inválido/expirado.
  String? verifyAccessToken(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(secret));
      final payload = jwt.payload;
      if (payload is Map && payload['type'] == 'access') {
        return payload['sub'] as String?;
      }
      return null;
    } on JWTException {
      return null;
    }
  }

  /// Refresh token opaco: se devuelve en claro al cliente y se persiste su hash.
  String generateRefreshToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(48, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String hashRefreshToken(String token) =>
      sha256.convert(utf8.encode(token)).toString();

  DateTime refreshExpiry() => DateTime.now().toUtc().add(refreshTokenTtl);
}
