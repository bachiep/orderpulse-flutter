import 'package:equatable/equatable.dart';
import 'package:orderpulse_flutter/core/result/result.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';

/// Measured result from firing 3 parallel authenticated API calls on an expired token.
class ParallelRefreshReport extends Equatable {
  const ParallelRefreshReport({
    required this.requestCount,
    required this.succeededCount,
    required this.refreshCallsExecuted,
    required this.traces,
  });

  final int requestCount;
  final int succeededCount;
  final int refreshCallsExecuted;
  final List<String> traces;

  @override
  List<Object?> get props => [
        requestCount,
        succeededCount,
        refreshCallsExecuted,
        traces,
      ];
}

/// Capability interface for interactive network/stream simulation in Demo mode.
abstract interface class NetworkSimulatorService {
  bool get isSupported;

  Future<Result<Order>> pushIncomingOrder();

  Future<Result<ParallelRefreshReport>> expireAccessTokenAndRunParallelRequests();

  Future<Result<void>> dropWebSocket({bool stayOffline = false});

  void restoreWebSocket();

  Future<Result<void>> simulateRefreshTokenExpired();
}
