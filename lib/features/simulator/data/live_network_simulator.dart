import 'package:orderpulse_flutter/core/error/failures.dart';
import 'package:orderpulse_flutter/core/result/result.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';
import 'package:orderpulse_flutter/features/simulator/domain/network_simulator_service.dart';

/// Live-mode stub ensuring simulator controls remain disabled on production endpoints.
class UnavailableNetworkSimulator implements NetworkSimulatorService {
  const UnavailableNetworkSimulator();

  @override
  bool get isSupported => false;

  @override
  Future<Result<Order>> pushIncomingOrder() async {
    return const Err(
      ValidationFailure('Interactive simulator is disabled in Live Server mode.'),
    );
  }

  @override
  Future<Result<ParallelRefreshReport>>
      expireAccessTokenAndRunParallelRequests() async {
    return const Err(
      ValidationFailure('Interactive simulator is disabled in Live Server mode.'),
    );
  }

  @override
  Future<Result<void>> dropWebSocket({bool stayOffline = false}) async {
    return const Err(
      ValidationFailure('Interactive simulator is disabled in Live Server mode.'),
    );
  }

  @override
  void restoreWebSocket() {}

  @override
  Future<Result<void>> simulateRefreshTokenExpired() async {
    return const Err(
      ValidationFailure('Interactive simulator is disabled in Live Server mode.'),
    );
  }
}
