import 'dart:math';

import 'package:dio/dio.dart';

/// Condiciones de red simuladas para demostrar comportamiento degradado.
class NetworkConditions {
  const NetworkConditions({
    this.offline = false,
    this.latency = Duration.zero,
    this.failureRate = 0,
  });

  final bool offline;
  final Duration latency;

  /// Probabilidad (0..1) de forzar un fallo de red por petición.
  final double failureRate;

  bool get isDegraded =>
      offline || latency > Duration.zero || failureRate > 0;

  static const NetworkConditions normal = NetworkConditions();

  NetworkConditions copyWith({
    bool? offline,
    Duration? latency,
    double? failureRate,
  }) =>
      NetworkConditions(
        offline: offline ?? this.offline,
        latency: latency ?? this.latency,
        failureRate: failureRate ?? this.failureRate,
      );
}

/// Interceptor que aplica las condiciones de red simuladas a cada petición.
class NetworkSimulatorInterceptor extends Interceptor {
  NetworkSimulatorInterceptor(this._read);

  final NetworkConditions Function() _read;
  final Random _random = Random();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final conditions = _read();
    if (conditions.offline) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'offline-simulated',
        ),
      );
      return;
    }
    if (conditions.latency > Duration.zero) {
      await Future<void>.delayed(conditions.latency);
    }
    if (conditions.failureRate > 0 &&
        _random.nextDouble() < conditions.failureRate) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'failure-simulated',
        ),
      );
      return;
    }
    handler.next(options);
  }
}
