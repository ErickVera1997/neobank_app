import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neobank_core/neobank_core.dart';
import 'package:neobank_mobile/src/core/error/app_exception.dart';
import 'package:neobank_mobile/src/core/network/api_client.dart';
import 'package:neobank_mobile/src/core/storage/cache_store.dart';
import 'package:neobank_mobile/src/core/storage/token_store.dart';

/// Adaptador Dio falso para simular respuestas y fallos sin red real.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object data, {int status = 200}) => ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

Dio _dio(Future<ResponseBody> Function(RequestOptions options) handler) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
  dio.httpClientAdapter = _FakeAdapter(handler);
  return dio;
}

AuthTokens _tokens() => const AuthTokens(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      expiresIn: 900,
    );

Map<String, dynamic> _sessionJson({String access = 'access-2'}) => {
      'user': {
        'id': 'u1',
        'name': 'Ana',
        'email': 'ana@neobank.com',
        'segment': 'premium',
        'createdAt': '2026-01-01T00:00:00.000Z',
      },
      'tokens': {
        'accessToken': access,
        'refreshToken': 'refresh-2',
        'expiresIn': 900,
      },
    };

void main() {
  group('ApiClient', () {
    test('guarda en caché y la usa cuando la red falla', () async {
      final tokens = InMemoryTokenStore();
      await tokens.write(_tokens());
      final cache = InMemoryCacheStore();

      final online = ApiClient(
        dio: _dio((_) async => _json({'value': 42})),
        refreshDio: _dio((_) async => _json(_sessionJson())),
        tokens: tokens,
        cache: cache,
      );

      final fresh = await online.getJson('/data', cacheKey: 'data');
      expect(fresh.fromCache, isFalse);
      expect(fresh.data['value'], 42);

      final offline = ApiClient(
        dio: _dio(
          (options) async => throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
        ),
        refreshDio: _dio((_) async => _json(_sessionJson())),
        tokens: tokens,
        cache: cache,
      );

      final cached = await offline.getJson('/data', cacheKey: 'data');
      expect(cached.fromCache, isTrue);
      expect(cached.data['value'], 42);
      expect(cached.cachedAt, isNotNull);
    });

    test('propaga error de red cuando no hay caché', () async {
      final client = ApiClient(
        dio: _dio(
          (options) async => throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
        ),
        refreshDio: _dio((_) async => _json(_sessionJson())),
        tokens: InMemoryTokenStore(),
        cache: InMemoryCacheStore(),
      );

      expect(
        () => client.getJson('/data'),
        throwsA(
          isA<AppException>()
              .having((e) => e.kind, 'kind', AppErrorKind.offline),
        ),
      );
    });

    test('ante 401 refresca la sesión y reintenta', () async {
      final tokens = InMemoryTokenStore();
      await tokens.write(_tokens());
      var attempts = 0;

      final dio = _dio((options) async {
        expect(options.headers['Authorization'], isNotNull);
        attempts++;
        if (attempts == 1) {
          return _json({'code': 'unauthorized'}, status: 401);
        }
        return _json({'ok': true});
      });
      dio.interceptors.add(AuthHeaderInterceptor(tokens));

      final client = ApiClient(
        dio: dio,
        refreshDio: _dio((_) async => _json(_sessionJson())),
        tokens: tokens,
        cache: InMemoryCacheStore(),
      );

      final result = await client.getJson('/secure');
      expect(result.data['ok'], isTrue);
      expect(attempts, 2);
      expect((await tokens.read())?.accessToken, 'access-2');
    });

    test('un 401 sin Authorization no borra una sesión recién guardada', () async {
      final tokens = InMemoryTokenStore();
      var attempts = 0;

      final client = ApiClient(
        dio: _dio((options) async {
          attempts++;
          expect(options.headers['Authorization'], isNull);
          return _json({'code': 'unauthorized'}, status: 401);
        }),
        refreshDio: _dio((_) async {
          fail('no debe refrescar una petición anónima');
        }),
        tokens: tokens,
        cache: InMemoryCacheStore(),
      );

      await tokens.write(_tokens());
      await expectLater(
        client.getJson('/config/bootstrap'),
        throwsA(
          isA<AppException>()
              .having((e) => e.kind, 'kind', AppErrorKind.unauthorized),
        ),
      );
      expect(attempts, 1);
      expect((await tokens.read())?.accessToken, 'access-1');
    });

    test('reintenta errores transitorios 5xx', () async {
      var attempts = 0;
      final client = ApiClient(
        dio: _dio((options) async {
          attempts++;
          if (attempts < 3) {
            return _json({'code': 'server_error'}, status: 503);
          }
          return _json({'ok': true});
        }),
        refreshDio: _dio((_) async => _json(_sessionJson())),
        tokens: InMemoryTokenStore(),
        cache: InMemoryCacheStore(),
      );

      final result = await client.getJson('/flaky');
      expect(result.data['ok'], isTrue);
      expect(attempts, 3);
    });
  });
}