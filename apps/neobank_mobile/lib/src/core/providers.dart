import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_config.dart';
import 'network/api_client.dart';
import 'network/connectivity_service.dart';
import 'network/network_conditions.dart';
import 'storage/cache_store.dart';
import 'storage/token_store.dart';

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.defaults);

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final cacheStoreProvider = Provider<CacheStore>((ref) => PrefsCacheStore());

final connectivityServiceProvider =
    Provider<ConnectivityService>((ref) => ConnectivityService());

/// Conectividad a nivel de sistema operativo (puede venir de WiFi, datos…).
final deviceOnlineProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onlineStream;
});

/// Simulador de condiciones de red controlado desde el panel de desarrollador.
class NetworkConditionsNotifier extends Notifier<NetworkConditions> {
  @override
  NetworkConditions build() => NetworkConditions.normal;

  void setOffline(bool value) =>
      state = state.copyWith(offline: value);

  void setLatency(Duration value) =>
      state = state.copyWith(latency: value);

  void setFailureRate(double value) =>
      state = state.copyWith(failureRate: value);

  void reset() => state = NetworkConditions.normal;
}

final networkConditionsProvider =
    NotifierProvider<NetworkConditionsNotifier, NetworkConditions>(
  NetworkConditionsNotifier.new,
);

Dio _baseDio(AppConfig config) => Dio(
      BaseOptions(
        baseUrl: config.apiBaseUrl,
        connectTimeout: config.requestTimeout,
        receiveTimeout: config.requestTimeout,
        sendTimeout: config.requestTimeout,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );

/// Dio para refrescar sesión: SIN interceptor de auth ni simulador.
final refreshDioProvider = Provider<Dio>((ref) {
  final dio = _baseDio(ref.watch(appConfigProvider));
  ref.onDispose(dio.close);
  return dio;
});

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final dio = _baseDio(config);
  dio.interceptors.add(AuthHeaderInterceptor(ref.watch(tokenStoreProvider)));
  if (config.simulatorEnabled) {
    dio.interceptors.add(
      NetworkSimulatorInterceptor(() => ref.read(networkConditionsProvider)),
    );
  }
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        logPrint: (line) => debugPrint(line.toString()),
      ),
    );
  }
  ref.onDispose(dio.close);
  return dio;
});

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    dio: ref.watch(dioProvider),
    refreshDio: ref.watch(refreshDioProvider),
    tokens: ref.watch(tokenStoreProvider),
    cache: ref.watch(cacheStoreProvider),
  ),
);
