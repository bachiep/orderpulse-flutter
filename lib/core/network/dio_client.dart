import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:orderpulse_flutter/core/config/app_config.dart';
import 'package:orderpulse_flutter/core/network/auth_interceptor.dart';
import 'package:orderpulse_flutter/core/network/token_storage.dart';

/// Configured HTTP client bundling timeouts, base URL, and [AuthInterceptor].
class DioClient {
  DioClient({
    required AppConfig config,
    required TokenStorage tokenStorage,
    required VoidCallback onSessionExpired,
    HttpClientAdapter? adapter,
    void Function(String message)? onTrace,
  }) {
    dio = Dio(
      BaseOptions(
        baseUrl: config.apiBaseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 8),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
    if (adapter != null) {
      dio.httpClientAdapter = adapter;
    }

    dio.interceptors.add(
      AuthInterceptor(
        tokenStorage: tokenStorage,
        bareDioFactory: createBareDio,
        onSessionExpired: onSessionExpired,
        onTrace: onTrace,
      ),
    );
  }

  late final Dio dio;

  /// Creates an unintercepted [Dio] sharing the current [HttpClientAdapter] and base options.
  Dio createBareDio() {
    final bare = Dio(dio.options);
    bare.httpClientAdapter = dio.httpClientAdapter;
    return bare;
  }
}
