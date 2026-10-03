import 'package:neobank_api/neobank_api.dart';
import 'package:test/test.dart';

void main() {
  group('PasswordHasher', () {
    final hasher = PasswordHasher(iterations: 1000);

    test('verifica una contraseña correcta', () {
      final encoded = hasher.hash('S3cret-Pass');
      expect(hasher.verify('S3cret-Pass', encoded), isTrue);
    });

    test('rechaza una contraseña incorrecta', () {
      final encoded = hasher.hash('S3cret-Pass');
      expect(hasher.verify('otra-clave', encoded), isFalse);
    });

    test('usa salt aleatorio (hashes distintos para la misma clave)', () {
      final a = hasher.hash('misma');
      final b = hasher.hash('misma');
      expect(a, isNot(equals(b)));
      expect(hasher.verify('misma', a), isTrue);
      expect(hasher.verify('misma', b), isTrue);
    });

    test('rechaza un formato inválido', () {
      expect(hasher.verify('x', 'no-es-un-hash'), isFalse);
    });
  });

  group('TokenService', () {
    final service = TokenService(
      secret: 'test-secret',
      accessTokenTtl: const Duration(minutes: 5),
      refreshTokenTtl: const Duration(days: 1),
    );

    test('emite y valida un access token', () {
      final token = service.issueAccessToken('user-1');
      expect(service.verifyAccessToken(token), 'user-1');
    });

    test('rechaza un token con firma distinta', () {
      final token = service.issueAccessToken('user-1');
      final other = TokenService(
        secret: 'otro-secret',
        accessTokenTtl: const Duration(minutes: 5),
        refreshTokenTtl: const Duration(days: 1),
      );
      expect(other.verifyAccessToken(token), isNull);
    });

    test('el refresh token se almacena hasheado', () {
      final token = service.generateRefreshToken();
      expect(service.hashRefreshToken(token), isNot(equals(token)));
    });
  });
}
