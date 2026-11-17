import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:orderpulse_flutter/core/network/token_storage.dart';

/// Serializes 401 recovery across concurrent requests so `/auth/refresh` runs at most once.
class AuthInterceptor extends QueuedInterceptorsWrapper {
  AuthInterceptor({
    required this.tokenStorage,
    required this.bareDioFactory,
    required this.onSessionExpired,
    this.refreshPath = '/auth/refresh',
    this.onTrace,
  });

  final TokenStorage tokenStorage;

  /// Provides an unintercepted [Dio] sharing the active [HttpClientAdapter] to
  /// avoid queue re-entrancy deadlocks when refreshing or retrying inside [onError].
  final Dio Function() bareDioFactory;
  final VoidCallback onSessionExpired;
  final String refreshPath;
  final void Function(String message)? onTrace;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['skipAuth'] == true) {
      handler.next(options);
      return;
    }

    final tokens = await tokenStorage.readTokens();
    if (tokens != null && tokens.accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final skipAuth = err.requestOptions.extra['skipAuth'] == true;
    final alreadyRetried = err.requestOptions.extra['isRetry'] == true;

    if (statusCode != 401 || skipAuth) {
      handler.next(err);
      return;
    }

    if (alreadyRetried) {
      onTrace?.call(
        'Retry for ${err.requestOptions.path} still returned 401; signing out.',
      );
      await tokenStorage.clearTokens();
      onSessionExpired();
      handler.next(err);
      return;
    }

    final failedToken = _extractBearerToken(err.requestOptions);
    final latestTokens = await tokenStorage.readTokens();

    if (latestTokens == null || latestTokens.refreshToken.isEmpty) {
      await tokenStorage.clearTokens();
      onSessionExpired();
      handler.next(err);
      return;
    }

    // Another queued 401 request already rotated the token while we waited.
    if (latestTokens.accessToken.isNotEmpty &&
        latestTokens.accessToken != failedToken) {
      onTrace?.call(
        'Queued ${err.requestOptions.method} ${err.requestOptions.path} reused rotated token.',
      );
      await _retryRequest(err, latestTokens.accessToken, handler);
      return;
    }

    onTrace?.call(
      '401 on ${err.requestOptions.method} ${err.requestOptions.path}; calling POST $refreshPath once.',
    );

    final bareDio = bareDioFactory();
    final AuthTokens rotatedTokens;
    try {
      final refreshResponse = await bareDio.post<Map<String, dynamic>>(
        refreshPath,
        data: {'refreshToken': latestTokens.refreshToken},
        options: Options(extra: {'skipAuth': true}),
      );
      final data = refreshResponse.data;
      if (data == null) {
        throw DioException(
          requestOptions: refreshResponse.requestOptions,
          response: refreshResponse,
          type: DioExceptionType.badResponse,
        );
      }
      rotatedTokens = AuthTokens.fromJson(data);
      if (rotatedTokens.accessToken.isEmpty ||
          rotatedTokens.refreshToken.isEmpty) {
        throw DioException(
          requestOptions: refreshResponse.requestOptions,
          response: refreshResponse,
          type: DioExceptionType.badResponse,
        );
      }
      await tokenStorage.saveTokens(rotatedTokens);
      onTrace?.call(
        'Refresh succeeded; retrying queued request ${err.requestOptions.path}.',
      );
    } on DioException catch (refreshErr) {
      onTrace?.call(
        'Refresh failed (${refreshErr.response?.statusCode ?? refreshErr.type.name}); clearing session.',
      );
      await tokenStorage.clearTokens();
      onSessionExpired();
      handler.reject(refreshErr);
      return;
    } catch (_) {
      await tokenStorage.clearTokens();
      onSessionExpired();
      handler.next(err);
      return;
    }

    await _retryRequest(err, rotatedTokens.accessToken, handler);
  }

  Future<void> _retryRequest(
    DioException originalErr,
    String accessToken,
    ErrorInterceptorHandler handler,
  ) async {
    final bareDio = bareDioFactory();
    final retryOptions = _copyRequestWithToken(
      originalErr.requestOptions,
      accessToken,
    );
    try {
      final response = await bareDio.fetch<dynamic>(retryOptions);
      handler.resolve(response);
    } on DioException catch (retryErr) {
      if (retryErr.response?.statusCode == 401) {
        await tokenStorage.clearTokens();
        onSessionExpired();
      }
      handler.reject(retryErr);
    }
  }

  RequestOptions _copyRequestWithToken(
    RequestOptions options,
    String accessToken,
  ) {
    final updatedHeaders = Map<String, dynamic>.from(options.headers)
      ..['Authorization'] = 'Bearer $accessToken';
    final updatedExtra = Map<String, dynamic>.from(options.extra)
      ..['isRetry'] = true;

    return options.copyWith(
      headers: updatedHeaders,
      extra: updatedExtra,
    );
  }

  String? _extractBearerToken(RequestOptions options) {
    final raw = options.headers['Authorization'];
    if (raw is String && raw.startsWith('Bearer ')) {
      return raw.substring(7).trim();
    }
    return null;
  }
}
