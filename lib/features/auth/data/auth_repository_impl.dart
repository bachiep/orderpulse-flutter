import 'package:dio/dio.dart';
import 'package:orderpulse_flutter/core/error/failures.dart';
import 'package:orderpulse_flutter/core/network/dio_error_mapper.dart';
import 'package:orderpulse_flutter/core/network/token_storage.dart';
import 'package:orderpulse_flutter/core/result/result.dart';
import 'package:orderpulse_flutter/features/auth/data/auth_dto.dart';
import 'package:orderpulse_flutter/features/auth/domain/auth_repository.dart';
import 'package:orderpulse_flutter/features/auth/domain/merchant_profile.dart';

/// Dio-backed [AuthRepository] serving both Live Server and Demo HTTP adapter modes.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required Dio dio,
    required TokenStorage tokenStorage,
  })  : _dio = dio,
        _tokenStorage = tokenStorage;

  final Dio _dio;
  final TokenStorage _tokenStorage;

  @override
  Future<Result<MerchantProfile>> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      return const Err(
        ValidationFailure('Email and password are required.'),
      );
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'email': normalizedEmail,
          'password': password,
        },
        options: Options(extra: {'skipAuth': true}),
      );

      final data = response.data;
      if (data == null) {
        return const Err(ServerFailure('Empty authentication response.'));
      }

      final session = AuthSessionDto.fromJson(data);
      if (session.tokens.accessToken.isEmpty ||
          session.tokens.refreshToken.isEmpty) {
        return const Err(ServerFailure('Authentication tokens missing.'));
      }

      await _tokenStorage.saveTokens(session.tokens);
      return Success(session.merchant.toDomain());
    } on DioException catch (error) {
      return Err(mapDioExceptionToFailure(error));
    } catch (_) {
      return const Err(UnexpectedFailure('Failed to sign in.'));
    }
  }

  @override
  Future<Result<MerchantProfile>> restoreSession() async {
    final existing = await _tokenStorage.readTokens();
    if (existing == null || existing.accessToken.isEmpty) {
      return const Err(UnauthorizedFailure('No active session found.'));
    }
    return fetchProfile();
  }

  @override
  Future<Result<MerchantProfile>> fetchProfile() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/merchant/profile');
      final data = response.data;
      if (data == null) {
        return const Err(ServerFailure('Empty merchant profile response.'));
      }
      return Success(MerchantProfileDto.fromJson(data).toDomain());
    } on DioException catch (error) {
      return Err(mapDioExceptionToFailure(error));
    } catch (_) {
      return const Err(UnexpectedFailure('Failed to load merchant profile.'));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      final tokens = await _tokenStorage.readTokens();
      if (tokens != null && tokens.refreshToken.isNotEmpty) {
        await _dio.post<void>(
          '/auth/logout',
          data: {'refreshToken': tokens.refreshToken},
          options: Options(extra: {'skipAuth': true}),
        );
      }
    } catch (_) {
      // Best-effort remote revocation; local credentials are always wiped.
    } finally {
      await _tokenStorage.clearTokens();
    }
    return const Success(null);
  }
}
