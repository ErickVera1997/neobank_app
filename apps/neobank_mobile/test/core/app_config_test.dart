import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neobank_mobile/src/core/config/app_config.dart';

void main() {
  group('AppConfig.resolveBaseUrl', () {
    test('respeta la URL definida en cualquier plataforma', () {
      expect(
        AppConfig.resolveBaseUrl(
          defined: 'https://api.neobank.dev',
          platform: TargetPlatform.android,
        ),
        'https://api.neobank.dev',
      );
      expect(
        AppConfig.resolveBaseUrl(
          defined: 'https://api.neobank.dev',
          platform: TargetPlatform.iOS,
        ),
        'https://api.neobank.dev',
      );
    });

    test('Android (emulador) usa el alias 10.0.2.2', () {
      expect(
        AppConfig.resolveBaseUrl(defined: '', platform: TargetPlatform.android),
        'http://10.0.2.2:8080',
      );
    });

    test('iOS usa localhost', () {
      expect(
        AppConfig.resolveBaseUrl(defined: '', platform: TargetPlatform.iOS),
        'http://localhost:8080',
      );
    });
  });
}