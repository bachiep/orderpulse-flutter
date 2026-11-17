import 'dart:async';

import 'package:orderpulse_flutter/features/orders/domain/order.dart';
import 'package:orderpulse_flutter/features/realtime/domain/order_realtime_event.dart';
import 'package:orderpulse_flutter/features/realtime/domain/order_realtime_source.dart';

/// Controllable in-memory stream source powering Demo Mode without background timers.
class DemoOrderRealtimeDataSource implements OrderRealtimeDataSource {
  StreamController<OrderRealtimeEvent>? _controller;
  bool _stayOffline = false;

  bool get isOfflineSimulated => _stayOffline;

  @override
  Future<Stream<OrderRealtimeEvent>> connect() async {
    if (_stayOffline) {
      throw StateError('Simulated WebSocket connection offline.');
    }
    await _controller?.close();
    final controller = StreamController<OrderRealtimeEvent>.broadcast();
    _controller = controller;
    return controller.stream;
  }

  @override
  Future<void> disconnect() async {
    final active = _controller;
    _controller = null;
    if (active != null && !active.isClosed) {
      await active.close();
    }
  }

  /// Pushes a live `ORDER_CREATED` frame onto the active socket session.
  void emitOrderCreated(Order order) {
    final controller = _controller;
    if (controller != null && !controller.isClosed) {
      controller.add(OrderCreatedEvent(order));
    }
  }

  /// Pushes an `ORDER_CANCELLED` frame onto the active socket session.
  void emitOrderCancelled(String orderId, String reason) {
    final controller = _controller;
    if (controller != null && !controller.isClosed) {
      controller.add(OrderCancelledEvent(orderId: orderId, reason: reason));
    }
  }

  /// Pushes a `RIDER_ASSIGNED` frame onto the active socket session.
  void emitRiderAssigned({
    required String orderId,
    required String riderName,
    required String riderPlate,
  }) {
    final controller = _controller;
    if (controller != null && !controller.isClosed) {
      controller.add(
        RiderAssignedEvent(
          orderId: orderId,
          riderName: riderName,
          riderPlate: riderPlate,
        ),
      );
    }
  }

  /// Drops the active stream with an error to trigger exponential backoff reconnect.
  void simulateConnectionDrop({bool stayOffline = false}) {
    _stayOffline = stayOffline;
    final controller = _controller;
    if (controller != null && !controller.isClosed) {
      controller.addError(StateError('Simulated socket connection drop'));
      unawaited(controller.close());
    }
  }

  /// Allows subsequent `connect()` attempts to succeed again.
  void restoreConnection() {
    _stayOffline = false;
  }
}
