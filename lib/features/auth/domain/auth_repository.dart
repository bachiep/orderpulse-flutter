import 'package:orderpulse_flutter/core/result/result.dart';
import 'package:orderpulse_flutter/features/auth/domain/merchant_profile.dart';

/// Authentication and merchant profile contract decoupled from transport/demo adapters.
abstract interface class AuthRepository {
  Future<Result<MerchantProfile>> signIn({
    required String email,
    required String password,
  });

  Future<Result<MerchantProfile>> restoreSession();

  Future<Result<MerchantProfile>> fetchProfile();

  Future<Result<void>> signOut();
}
