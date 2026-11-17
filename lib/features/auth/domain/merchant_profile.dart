import 'package:equatable/equatable.dart';

/// Authenticated merchant store profile displayed on the dispatch header.
class MerchantProfile extends Equatable {
  const MerchantProfile({
    required this.id,
    required this.merchantName,
    required this.branchName,
    required this.email,
  });

  final String id;
  final String merchantName;
  final String branchName;
  final String email;

  @override
  List<Object?> get props => [id, merchantName, branchName, email];
}
