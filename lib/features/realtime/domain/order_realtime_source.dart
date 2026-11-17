import 'package:orderpulse_flutter/features/realtime/domain/order_realtime_event.dart';

/// Transport boundary for live merchant order stream events.
abstract interface class OrderRealtimeDataSource {
  Future<Stream<OrderRealtimeEvent>> connect();
  Future<void> disconnect();
}
