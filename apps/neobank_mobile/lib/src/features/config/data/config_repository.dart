import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neobank_core/neobank_core.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';

/// Bootstrap enriquecido con metadatos de caché.
class BootstrapResult {
  const BootstrapResult({
    required this.bootstrap,
    this.fromCache = false,
    this.cachedAt,
  });

  /// Bootstrap neutro para cuando no hay sesión (no dispara red).
  factory BootstrapResult.unauthenticated() => BootstrapResult(
        bootstrap: AppBootstrap(
          user: User(
            id: 'guest',
            name: 'Invitado',
            email: '',
            segment: UserSegment.standard,
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
          version: 'guest',
          flags: const [],
          home: const [],
          offers: const [],
          theme: const AppThemeConfig(),
        ),
      );

  final AppBootstrap bootstrap;
  final bool fromCache;
  final DateTime? cachedAt;
}

/// Obtiene la configuración personalizada del usuario.
class ConfigRepository {
  ConfigRepository(this._client);

  final ApiClient _client;

  Future<BootstrapResult> bootstrap() async {
    final result = await _client.getJson(
      ApiPaths.bootstrap,
      cacheKey: 'bootstrap',
    );
    return BootstrapResult(
      bootstrap: AppBootstrap.fromJson(result.data),
      fromCache: result.fromCache,
      cachedAt: result.cachedAt,
    );
  }
}

final configRepositoryProvider = Provider<ConfigRepository>(
  (ref) => ConfigRepository(ref.watch(apiClientProvider)),
);
