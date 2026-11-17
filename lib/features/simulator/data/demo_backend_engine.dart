import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Stateful in-memory merchant backend serving Demo Mode HTTP traffic over Dio.
class DemoBackendEngine {
  DemoBackendEngine({
    this.simulatedLatency = const Duration(milliseconds: 90),
  });

  final Duration simulatedLatency;

  int _tokenVersion = 1;
  String _activeAccessToken = 'demo-access-v1';
  String _activeRefreshToken = 'demo-refresh-v1';
  bool _accessExpired = false;
  bool _refreshExpired = false;

  int refreshCallCount = 0;

  String get activeAccessToken => _activeAccessToken;
  String get activeRefreshToken => _activeRefreshToken;
  bool get isAccessExpired => _accessExpired;
  bool get isRefreshExpired => _refreshExpired;

  /// Marks the active access token expired so subsequent protected requests return `401`.
  void expireAccessToken() {
    _accessExpired = true;
  }

  /// Marks both access and refresh tokens expired to test forced session logout.
  void expireRefreshToken() {
    _accessExpired = true;
    _refreshExpired = true;
  }

  /// Resets token state for a fresh Demo login session.
  void resetSession() {
    _tokenVersion = 1;
    _activeAccessToken = 'demo-access-v1';
    _activeRefreshToken = 'demo-refresh-v1';
    _accessExpired = false;
    _refreshExpired = false;
    refreshCallCount = 0;
  }

  Future<ResponseBody> handleRequest(
    RequestOptions options,
    Map<String, dynamic>? body,
  ) async {
    if (simulatedLatency > Duration.zero) {
      await Future<void>.delayed(simulatedLatency);
    }

    final path = options.path;
    final method = options.method.toUpperCase();

    if (method == 'POST' && path == '/auth/login') {
      resetSession();
      final email = (body?['email'] as String?)?.trim();
      return _jsonResponse(200, {
        'accessToken': _activeAccessToken,
        'refreshToken': _activeRefreshToken,
        'expiresAt':
            DateTime.now().toUtc().add(const Duration(minutes: 15)).toIso8601String(),
        'merchant': {
          'id': 'merchant-demo-01',
          'merchantName': 'OrderPulse Kitchen - Demo',
          'branchName': 'District 1 Flagship',
          'email': (email != null && email.isNotEmpty)
              ? email
              : 'merchant@orderpulse.demo',
        },
      });
    }

    if (method == 'POST' && path == '/auth/refresh') {
      refreshCallCount += 1;
      final submittedRefresh = body?['refreshToken'] as String?;
      if (_refreshExpired || submittedRefresh != _activeRefreshToken) {
        return _jsonResponse(401, {
          'message': 'Refresh token expired or revoked.',
        });
      }
      _tokenVersion += 1;
      _activeAccessToken = 'demo-access-v$_tokenVersion';
      _activeRefreshToken = 'demo-refresh-v$_tokenVersion';
      _accessExpired = false;
      return _jsonResponse(200, {
        'accessToken': _activeAccessToken,
        'refreshToken': _activeRefreshToken,
        'expiresAt':
            DateTime.now().toUtc().add(const Duration(minutes: 15)).toIso8601String(),
      });
    }

    if (method == 'POST' && path == '/auth/logout') {
      return _jsonResponse(200, {'ok': true});
    }

    // All remaining endpoints require a valid, unexpired Bearer token.
    if (!_isAuthorized(options)) {
      return _jsonResponse(401, {
        'message': 'Access token expired or invalid.',
      });
    }

    if (method == 'GET' && path == '/merchant/profile') {
      return _jsonResponse(200, {
        'id': 'merchant-demo-01',
        'merchantName': 'OrderPulse Kitchen - Demo',
        'branchName': 'District 1 Flagship',
        'email': 'merchant@orderpulse.demo',
      });
    }

    return _jsonResponse(404, {'message': 'Route not found: $method $path'});
  }

  bool _isAuthorized(RequestOptions options) {
    if (_accessExpired) return false;
    final authHeader = options.headers['Authorization'] as String?;
    return authHeader == 'Bearer $_activeAccessToken';
  }

  ResponseBody _jsonResponse(int statusCode, Map<String, dynamic> payload) {
    return ResponseBody.fromString(
      jsonEncode(payload),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

/// Custom Dio [HttpClientAdapter] routing requests to [DemoBackendEngine] in-memory.
class DemoBackendHttpAdapter implements HttpClientAdapter {
  DemoBackendHttpAdapter(this.engine);

  final DemoBackendEngine engine;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Map<String, dynamic>? jsonBody;
    if (requestStream != null) {
      final chunks = await requestStream.toList();
      final bytes = chunks.expand((e) => e).toList();
      if (bytes.isNotEmpty) {
        final decoded = jsonDecode(utf8.decode(bytes));
        if (decoded is Map<String, dynamic>) {
          jsonBody = decoded;
        }
      }
    } else if (options.data is Map<String, dynamic>) {
      jsonBody = options.data as Map<String, dynamic>;
    }

    return engine.handleRequest(options, jsonBody);
  }

  @override
  void close({bool force = false}) {}
}
