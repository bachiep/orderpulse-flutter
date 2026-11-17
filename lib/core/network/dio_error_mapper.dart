import 'package:dio/dio.dart';
import 'package:orderpulse_flutter/core/error/failures.dart';

/// Maps low-level [DioException] transport and HTTP status errors into typed domain [Failure]s.
Failure mapDioExceptionToFailure(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const NetworkFailure('Request timed out. Please retry.');
    case DioExceptionType.connectionError:
      return const NetworkFailure(
        'Cannot reach server. Verify network or API URL (10.0.2.2 for Android Emulator).',
      );
    case DioExceptionType.cancel:
      return const UnexpectedFailure('Request cancelled.');
    case DioExceptionType.badCertificate:
      return const NetworkFailure('TLS certificate verification failed.');
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      final statusCode = error.response?.statusCode;
      final serverMessage = _extractErrorMessage(error.response?.data);
      if (statusCode == 401) {
        return UnauthorizedFailure(
          serverMessage ?? 'Session expired or invalid credentials.',
        );
      }
      if (statusCode == 400 || statusCode == 422) {
        return ValidationFailure(
          serverMessage ?? 'Invalid request input.',
          code: '$statusCode',
        );
      }
      if (statusCode == 409) {
        return ConflictFailure(
          serverMessage ?? 'Order state changed concurrently. Refreshing.',
          code: '409',
        );
      }
      if (statusCode != null && statusCode >= 500) {
        return ServerFailure(
          serverMessage ?? 'Server error ($statusCode). Please try again.',
          statusCode: statusCode,
        );
      }
      if (statusCode != null) {
        return ServerFailure(
          serverMessage ?? 'Request failed ($statusCode).',
          statusCode: statusCode,
        );
      }
      return NetworkFailure(
        error.message ?? 'Network error occurred.',
      );
  }
}

String? _extractErrorMessage(dynamic data) {
  if (data is Map<String, dynamic>) {
    final msg = data['message'] ?? data['error'] ?? data['detail'];
    if (msg is String && msg.trim().isNotEmpty) {
      return msg.trim();
    }
  }
  return null;
}
