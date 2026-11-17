import 'package:equatable/equatable.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';

/// Realtime events pushed from the merchant order WebSocket stream.
sealed class OrderRealtimeEvent extends Equatable {
  const OrderRealtimeEvent();

  @override
  List<Object?> get props => [];
}

final class OrderCreatedEvent extends OrderRealtimeEvent {
  const OrderCreatedEvent(this.order);

  final Order order;

  @override
  List<Object?> get props => [order];
}

final class OrderCancelledEvent extends OrderRealtimeEvent {
  const OrderCancelledEvent({
    required this.orderId,
    required this.reason,
  });

  final String orderId;
  final String reason;

  @override
  List<Object?> get props => [orderId, reason];
}

final class RiderAssignedEvent extends OrderRealtimeEvent {
  const RiderAssignedEvent({
    required this.orderId,
    required this.riderName,
    required this.riderPlate,
  });

  final String orderId;
  final String riderName;
  final String riderPlate;

  @override
  List<Object?> get props => [orderId, riderName, riderPlate];
}
