import 'package:dio/dio.dart';
import 'package:orderpulse_flutter/core/network/dio_error_mapper.dart';
import 'package:orderpulse_flutter/core/result/result.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';
import 'package:orderpulse_flutter/features/realtime/data/demo_order_realtime_source.dart';
import 'package:orderpulse_flutter/features/simulator/data/demo_backend_engine.dart';
import 'package:orderpulse_flutter/features/simulator/domain/network_simulator_service.dart';

/// Collects live [AuthInterceptor] log lines for diagnostic display in the Simulator sheet.
class AuthTraceBuffer {
  final List<String> _entries = [];

  void add(String entry) {
    _entries.add(entry);
  }

  List<String> takeAll() {
    final copy = List<String>.from(_entries);
    _entries.clear();
    return copy;
  }
}

/// Interactive Demo simulator wired directly to the active [Dio] + [DemoBackendEngine].
class DemoNetworkSimulator implements NetworkSimulatorService {
  DemoNetworkSimulator({
    required DemoBackendEngine engine,
    required DemoOrderRealtimeDataSource realtimeSource,
    required Dio dio,
    required AuthTraceBuffer traceBuffer,
  })  : _engine = engine,
        _realtimeSource = realtimeSource,
        _dio = dio,
        _traceBuffer = traceBuffer;

  final DemoBackendEngine _engine;
  final DemoOrderRealtimeDataSource _realtimeSource;
  final Dio _dio;
  final AuthTraceBuffer _traceBuffer;

  @override
  bool get isSupported => true;

  @override
  Future<Result<Order>> pushIncomingOrder() async {
    final order = _engine.createIncomingDemoOrder();
    _realtimeSource.emitOrderCreated(order);
    return Success(order);
  }

  @override
  Future<Result<ParallelRefreshReport>>
      expireAccessTokenAndRunParallelRequests() async {
    _traceBuffer.takeAll();
    final beforeRefreshCount = _engine.refreshCallCount;
    _engine.expireAccessToken();

    try {
      final responses = await Future.wait<Response<dynamic>>([
        _dio.get<Map<String, dynamic>>('/orders'),
        _dio.get<Map<String, dynamic>>('/orders/stats'),
        _dio.get<Map<String, dynamic>>('/merchant/profile'),
      ]);

      final succeededCount =
          responses.where((r) => r.statusCode == 200).length;
      final refreshDelta = _engine.refreshCallCount - beforeRefreshCount;

      return Success(
        ParallelRefreshReport(
          requestCount: responses.length,
          succeededCount: succeededCount,
          refreshCallsExecuted: refreshDelta,
          traces: _traceBuffer.takeAll(),
        ),
      );
    } on DioException catch (error) {
      return Err(mapDioExceptionToFailure(error));
    }
  }

  @override
  Future<Result<void>> dropWebSocket({bool stayOffline = false}) async {
    _realtimeSource.simulateConnectionDrop(stayOffline: stayOffline);
    return const Success(null);
  }

  @override
  void restoreWebSocket() {
    _realtimeSource.restoreConnection();
  }

  @override
  Future<Result<void>> simulateRefreshTokenExpired() async {
    _engine.expireRefreshToken();
    try {
      await _dio.get<Map<String, dynamic>>('/merchant/profile');
      return const Success(null);
    } on DioException catch (error) {
      return Err(mapDioExceptionToFailure(error));
    }
  }
}
