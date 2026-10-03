import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Hashing de contraseñas con PBKDF2-HMAC-SHA256.
///
/// Formato almacenado: `pbkdf2_sha256$<iteraciones>$<saltB64>$<hashB64>`.
/// Se eligió PBKDF2 por ser estándar (NIST) y no requerir dependencias
/// nativas, manteniendo el backend portable.
class PasswordHasher {
  PasswordHasher({this.iterations = 120000, Random? random})
      : _random = random ?? Random.secure();

  final int iterations;
  final Random _random;

  static const int _saltLength = 16;
  static const int _keyLength = 32;

  String hash(String password) {
    final salt = _randomBytes(_saltLength);
    final derived = _pbkdf2(
      utf8.encode(password),
      salt,
      iterations,
      _keyLength,
    );
    return 'pbkdf2_sha256\$$iterations\$${base64.encode(salt)}\$${base64.encode(derived)}';
  }

  bool verify(String password, String encoded) {
    final parts = encoded.split(r'$');
    if (parts.length != 4 || parts.first != 'pbkdf2_sha256') return false;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null) return false;
    final salt = base64.decode(parts[2]);
    final expected = base64.decode(parts[3]);
    final actual = _pbkdf2(utf8.encode(password), salt, iterations, expected.length);
    return _constantTimeEquals(expected, actual);
  }

  Uint8List _randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  static Uint8List _pbkdf2(
    List<int> password,
    List<int> salt,
    int iterations,
    int length,
  ) {
    final hmac = Hmac(sha256, password);
    final blockCount = (length / 32).ceil();
    final output = <int>[];
    for (var block = 1; block <= blockCount; block++) {
      var u = hmac.convert(<int>[...salt, ..._intToBytes(block)]).bytes;
      final t = List<int>.from(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      output.addAll(t);
    }
    return Uint8List.fromList(output.sublist(0, length));
  }

  static List<int> _intToBytes(int value) => <int>[
        (value >> 24) & 0xff,
        (value >> 16) & 0xff,
        (value >> 8) & 0xff,
        value & 0xff,
      ];

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
