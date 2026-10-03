import 'package:dio/dio.dart';
import 'package:neobank_core/neobank_core.dart';

import '../error/app_exception.dart';
import '../storage/cache_store.dart';
import '../storage/token_store.dart';

/// Respuesta de API con metadatos de caché.
class ApiResult {
  const ApiResult({required this.data, this.fromCache = false, this.cachedAt});

  final Map<String, dynamic> data;
  final bool fromCache;
  final DateTime? cachedAt;
}

/// Inyecta el access token vigente en cada petición.
class AuthHeaderInterceptor extends Interceptor {
  AuthHeaderInterceptor(this._tokens);

  final TokenStore _tokens;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final tokens = await _tokens.read();
    if (tokens != null) {
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }
    handler.next(options);
  }
}

/// Cliente HTTP con reintentos, refresh automático de sesión y caché offline.
class ApiClient {
  ApiClient({
    required this.dio,
    required this.refreshDio,
    required TokenStore tokens,
    required CacheStore cache,
  })  : _tokens = tokens,
        _cache = cache;

  final Dio dio;

  /// Dio sin interceptores de auth, usado sólo para refrescar la sesión.
  final Dio refreshDio;
  final TokenStore _tokens;
  final CacheStore _cache;

  Future<bool>? _refreshInFlight;

  static const int _maxRetries = 2;

  Future<ApiResult> getJson(String path, {String? cacheKey}) async {
    try {
      final response = await _send(() => dio.get<dynamic>(path));
      final data = _asMap(response.data);
      if (cacheKey != null) {
        await _cache.put(cacheKey, data);
      }
      return ApiResult(data: data);
    } on AppException catch (error) {
      if (cacheKey != null && error.isRetryable) {
        final cached = await _cache.get(cacheKey);
        if (cached != null) {
          return ApiResult(
            data: cached.value,
            fromCache: true,
            cachedAt: cached.storedAt,
          );
        }
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> postJson(String path, {Object? body}) async {
    final response = await _send(() => dio.post<dynamic>(path, data: body));
    return _asMap(response.data);
  }

  Future<void> postVoid(String path, {Object? body}) async {
    await _send(() => dio.post<dynamic>(path, data: body));
  }

  Future<void> clearCache() => _cache.clear();

  Future<Response<dynamic>> _send(
    Future<Response<dynamic>> Function() send, {
    bool allowRefresh = true,
  }) async {
    var delay = const Duration(milliseconds: 400);
    for (var attempt = 0;; attempt++) {
      try {
        return await send();
      } on DioException catch (error) {
        if (error.response?.statusCode == 401 && allowRefresh) {
          if (await _refreshSession()) {
            return _send(send, allowRefresh: false);
          }
        }
        final appError = AppException.fromDio(error);
        if (attempt < _maxRetries && appError.isRetryable) {
          await Future<void>.delayed(delay);
          delay *= 2;
          continue;
        }
        throw appError;
      }
    }
  }

  /// Refresco "single-flight": varias peticiones comparten un mismo intento.
  Future<bool> _refreshSession() {
    return _refreshInFlight ??=
        _performRefresh().whenComplete(() => _refreshInFlight = null);
  }

  Future<bool> _performRefresh() async {
    final current = await _tokens.read();
    if (current == null) return false;
    try {
      final response = await refreshDio.post<dynamic>(
        ApiPaths.refresh,
        data: {'refreshToken': current.refreshToken},
      );
      final session = AuthSession.fromJson(_asMap(response.data));
      await _tokens.write(session.tokens);
      return true;
    } catch (_) {
      await _tokens.clear();
      return false;
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }
}
