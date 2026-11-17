import 'package:orderpulse_flutter/core/result/result.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';

/// Contract for querying orders, shift metrics, and dispatching status transitions.
abstract interface class OrderRepository {
  Future<Result<OrderPage>> fetchOrders({
    OrderStatus? status,
    String query = '',
    int page = 1,
    int pageSize = 8,
  });

  Future<Result<Order>> fetchOrderById(String orderId);

  Future<Result<MerchantShiftStats>> fetchShiftStats();

  Future<Result<Order>> transitionOrder({
    required String orderId,
    required OrderStatus targetStatus,
    String? rejectionReason,
  });
}
