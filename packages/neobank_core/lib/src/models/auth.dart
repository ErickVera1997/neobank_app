import '../json_utils.dart';
import 'user.dart';

/// Par de tokens emitidos por el backend.
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    this.tokenType = 'Bearer',
  });

  final String accessToken;
  final String refreshToken;

  /// Vigencia del access token en segundos.
  final int expiresIn;
  final String tokenType;

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        accessToken: jsonString(json, 'accessToken'),
        refreshToken: jsonString(json, 'refreshToken'),
        expiresIn: jsonInt(json, 'expiresIn', fallback: 900),
        tokenType: jsonString(json, 'tokenType', fallback: 'Bearer'),
      );

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresIn': expiresIn,
        'tokenType': tokenType,
      };
}

/// Sesión autenticada: usuario + tokens.
class AuthSession {
  const AuthSession({required this.user, required this.tokens});

  final User user;
  final AuthTokens tokens;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        user: User.fromJson(jsonMap(json, 'user')),
        tokens: AuthTokens.fromJson(jsonMap(json, 'tokens')),
      );

  Map<String, dynamic> toJson() => {
        'user': user.toJson(),
        'tokens': tokens.toJson(),
      };
}

/// Reto OTP devuelto al solicitar un código.
class OtpChallenge {
  const OtpChallenge({
    required this.challengeId,
    required this.expiresIn,
    this.devCode,
  });

  final String challengeId;
  final int expiresIn;

  /// Sólo presente en entornos de desarrollo/demo para poder probar el flujo.
  final String? devCode;

  factory OtpChallenge.fromJson(Map<String, dynamic> json) => OtpChallenge(
        challengeId: jsonString(json, 'challengeId'),
        expiresIn: jsonInt(json, 'expiresIn', fallback: 300),
        devCode: jsonStringOrNull(json, 'devCode'),
      );

  Map<String, dynamic> toJson() => {
        'challengeId': challengeId,
        'expiresIn': expiresIn,
        'devCode': devCode,
      };
}
