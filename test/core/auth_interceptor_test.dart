import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderpulse_flutter/core/config/app_config.dart';
import 'package:orderpulse_flutter/core/network/dio_client.dart';
import 'package:orderpulse_flutter/core/network/token_storage.dart';

class _Concurrent401TestAdapter implements HttpClientAdapter {
  _Concurrent401TestAdapter({
    this.failRefreshWith401 = false,
    this.failRetryWith401 = false,
  });

  final bool failRefreshWith401;
  final bool failRetryWith401;

  String validAccessToken = 'expired-token-v1';
  String validRefreshToken = 'refresh-token-v1';
  bool accessExpired = true;

  int refreshCalls = 0;
  final List<String> requestLog = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    requestLog.add('${options.method} ${options.path}');

    if (options.path == '/auth/refresh') {
      refreshCalls += 1;
      if (failRefreshWith401) {
        return _json(401, {'message': 'Refresh token revoked'});
      }
      validAccessToken = 'fresh-token-v2';
      validRefreshToken = 'refresh-token-v2';
      accessExpired = false;
      return _json(200, {
        'accessToken': validAccessToken,
        'refreshToken': validRefreshToken,
      });
    }

    if (options.path == '/auth/login') {
      return _json(401, {'message': 'Invalid credentials'});
    }

    final authHeader = options.headers['Authorization'] as String?;
    if (accessExpired ||
        failRetryWith401 ||
        authHeader != 'Bearer $validAccessToken') {
      return _json(401, {'message': 'Token expired'});
    }

    return _json(200, {'path': options.path, 'ok': true});
  }

  ResponseBody _json(int statusCode, Map<String, dynamic> data) {
    return ResponseBody.fromString(
      jsonEncode(data),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const testConfig = AppConfig(
    environment: AppEnvironment.live,
    apiBaseUrl: 'https://api.orderpulse.test',
    wsBaseUrl: 'wss://api.orderpulse.test/ws/orders',
  );

  group('AuthInterceptor (QueuedInterceptorsWrapper)', () {
    test(
      '3 concurrent 401 requests trigger exactly 1 /auth/refresh and all 3 retry & succeed',
      () async {
        final storage = InMemoryTokenStorage(
          initialTokens: const AuthTokens(
            accessToken: 'expired-token-v1',
            refreshToken: 'refresh-token-v1',
          ),
        );
        final adapter = _Concurrent401TestAdapter();
        var sessionExpiredCount = 0;

        final client = DioClient(
          config: testConfig,
          tokenStorage: storage,
          adapter: adapter,
          onSessionExpired: () => sessionExpiredCount += 1,
        );

        final results = await Future.wait([
          client.dio.get<Map<String, dynamic>>('/orders'),
          client.dio.get<Map<String, dynamic>>('/orders/stats'),
          client.dio.get<Map<String, dynamic>>('/merchant/profile'),
        ]);

        expect(results, hasLength(3));
        for (final response in results) {
          expect(response.statusCode, 200);
          expect(response.data?['ok'], isTrue);
        }

        expect(adapter.refreshCalls, 1);
        expect(sessionExpiredCount, 0);

        final updatedTokens = await storage.readTokens();
        expect(updatedTokens?.accessToken, 'fresh-token-v2');
        expect(updatedTokens?.refreshToken, 'refresh-token-v2');
      },
    );

    test('refresh 401 clears tokens and invokes onSessionExpired', () async {
      final storage = InMemoryTokenStorage(
        initialTokens: const AuthTokens(
          accessToken: 'expired-token-v1',
          refreshToken: 'revoked-refresh',
        ),
      );
      final adapter = _Concurrent401TestAdapter(failRefreshWith401: true);
      var sessionExpiredCount = 0;

      final client = DioClient(
        config: testConfig,
        tokenStorage: storage,
        adapter: adapter,
        onSessionExpired: () => sessionExpiredCount += 1,
      );

      await expectLater(
        () => client.dio.get<Map<String, dynamic>>('/orders'),
        throwsA(isA<DioException>()),
      );

      expect(adapter.refreshCalls, 1);
      expect(sessionExpiredCount, 1);
      expect(await storage.readTokens(), isNull);
    });

    test('retry 401 prevents infinite refresh loop and logs out', () async {
      final storage = InMemoryTokenStorage(
        initialTokens: const AuthTokens(
          accessToken: 'expired-token-v1',
          refreshToken: 'refresh-token-v1',
        ),
      );
      final adapter = _Concurrent401TestAdapter(failRetryWith401: true);
      var sessionExpiredCount = 0;

      final client = DioClient(
        config: testConfig,
        tokenStorage: storage,
        adapter: adapter,
        onSessionExpired: () => sessionExpiredCount += 1,
      );

      await expectLater(
        () => client.dio.get<Map<String, dynamic>>('/orders'),
        throwsA(isA<DioException>()),
      );

      expect(adapter.refreshCalls, 1);
      expect(sessionExpiredCount, 1);
      expect(await storage.readTokens(), isNull);
    });

    test('skipAuth request returning 401 does not trigger refresh', () async {
      final storage = InMemoryTokenStorage(
        initialTokens: const AuthTokens(
          accessToken: 'expired-token-v1',
          refreshToken: 'refresh-token-v1',
        ),
      );
      final adapter = _Concurrent401TestAdapter();
      var sessionExpiredCount = 0;

      final client = DioClient(
        config: testConfig,
        tokenStorage: storage,
        adapter: adapter,
        onSessionExpired: () => sessionExpiredCount += 1,
      );

      await expectLater(
        () => client.dio.post<Map<String, dynamic>>(
          '/auth/login',
          data: {'email': 'a@b.com', 'password': 'wrong'},
          options: Options(extra: {'skipAuth': true}),
        ),
        throwsA(isA<DioException>()),
      );

      expect(adapter.refreshCalls, 0);
      expect(sessionExpiredCount, 0);
      expect((await storage.readTokens())?.accessToken, 'expired-token-v1');
    });
  });
}
