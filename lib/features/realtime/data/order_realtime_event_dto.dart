import 'dart:convert';

import 'package:orderpulse_flutter/features/orders/data/order_dto.dart';
import 'package:orderpulse_flutter/features/realtime/domain/order_realtime_event.dart';

/// Parses raw WebSocket frames into typed [OrderRealtimeEvent] instances.
abstract final class OrderRealtimeEventDto {
  static OrderRealtimeEvent? tryParse(dynamic rawMessage) {
    final Map<String, dynamic>? decoded;
    if (rawMessage is String) {
      try {
        final jsonValue = jsonDecode(rawMessage);
        decoded = jsonValue is Map<String, dynamic> ? jsonValue : null;
      } catch (_) {
        return null;
      }
    } else if (rawMessage is Map<String, dynamic>) {
      decoded = rawMessage;
    } else {
      return null;
    }

    if (decoded == null) return null;
    final type = (decoded['type'] as String? ?? '').trim().toUpperCase();
    final payload = decoded['payload'] as Map<String, dynamic>? ?? decoded;

    return switch (type) {
      'ORDER_CREATED' => OrderCreatedEvent(OrderDto.fromJson(payload)),
      'ORDER_CANCELLED' => OrderCancelledEvent(
          orderId: payload['orderId'] as String? ?? '',
          reason: payload['reason'] as String? ?? 'Cancelled by customer',
        ),
      'RIDER_ASSIGNED' => RiderAssignedEvent(
          orderId: payload['orderId'] as String? ?? '',
          riderName: payload['riderName'] as String? ?? 'Courier',
          riderPlate: payload['riderPlate'] as String? ?? '',
        ),
      _ => null,
    };
  }
}
