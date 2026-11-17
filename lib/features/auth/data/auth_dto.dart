import 'package:orderpulse_flutter/core/network/token_storage.dart';
import 'package:orderpulse_flutter/features/auth/domain/merchant_profile.dart';

/// JSON mapper for merchant authentication and profile responses.
class MerchantProfileDto {
  const MerchantProfileDto({
    required this.id,
    required this.merchantName,
    required this.branchName,
    required this.email,
  });

  factory MerchantProfileDto.fromJson(Map<String, dynamic> json) {
    return MerchantProfileDto(
      id: json['id'] as String? ?? 'merchant-1',
      merchantName: json['merchantName'] as String? ?? 'OrderPulse Merchant',
      branchName: json['branchName'] as String? ?? 'District 1 Flagship',
      email: json['email'] as String? ?? 'merchant@orderpulse.local',
    );
  }

  final String id;
  final String merchantName;
  final String branchName;
  final String email;

  MerchantProfile toDomain() {
    return MerchantProfile(
      id: id,
      merchantName: merchantName,
      branchName: branchName,
      email: email,
    );
  }
}

/// Login response carrying JWT pair and authenticated merchant profile.
class AuthSessionDto {
  const AuthSessionDto({
    required this.tokens,
    required this.merchant,
  });

  factory AuthSessionDto.fromJson(Map<String, dynamic> json) {
    final merchantMap = json['merchant'] as Map<String, dynamic>? ?? const {};
    return AuthSessionDto(
      tokens: AuthTokens.fromJson(json),
      merchant: MerchantProfileDto.fromJson(merchantMap),
    );
  }

  final AuthTokens tokens;
  final MerchantProfileDto merchant;
}
