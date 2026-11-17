import 'package:orderpulse_flutter/features/orders/domain/order.dart';

/// JSON mapper for order items, orders, paginated responses, and shift stats.
class OrderDto {
  static OrderItem itemFromJson(Map<String, dynamic> json) {
    return OrderItem(
      name: json['name'] as String? ?? 'Menu Item',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPriceVnd: (json['unitPriceVnd'] as num?)?.toInt() ?? 0,
      note: json['note'] as String?,
    );
  }

  static Map<String, dynamic> itemToJson(OrderItem item) => {
        'name': item.name,
        'quantity': item.quantity,
        'unitPriceVnd': item.unitPriceVnd,
        if (item.note != null) 'note': item.note,
      };

  static Order fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(itemFromJson)
        .toList(growable: false);

    return Order(
      id: json['id'] as String? ?? '',
      customerName: json['customerName'] as String? ?? 'Customer',
      customerPhone: json['customerPhone'] as String? ?? '',
      items: items,
      totalAmountVnd: (json['totalAmountVnd'] as num?)?.toInt() ?? 0,
      status: OrderStatus.fromApi(json['status'] as String? ?? 'NEW'),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      kitchenNotes: json['kitchenNotes'] as String?,
      riderName: json['riderName'] as String?,
      riderPlate: json['riderPlate'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
    );
  }

  static Map<String, dynamic> toJson(Order order) => {
        'id': order.id,
        'customerName': order.customerName,
        'customerPhone': order.customerPhone,
        'items': order.items.map(itemToJson).toList(growable: false),
        'totalAmountVnd': order.totalAmountVnd,
        'status': order.status.apiValue,
        'createdAt': order.createdAt.toIso8601String(),
        'updatedAt': order.updatedAt.toIso8601String(),
        if (order.kitchenNotes != null) 'kitchenNotes': order.kitchenNotes,
        if (order.riderName != null) 'riderName': order.riderName,
        if (order.riderPlate != null) 'riderPlate': order.riderPlate,
        if (order.rejectionReason != null)
          'rejectionReason': order.rejectionReason,
      };

  static OrderPage pageFromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return OrderPage(
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList(growable: false),
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 8,
      hasMore: json['hasMore'] as bool? ?? false,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? rawItems.length,
    );
  }

  static MerchantShiftStats statsFromJson(Map<String, dynamic> json) {
    return MerchantShiftStats(
      activeCount: (json['activeCount'] as num?)?.toInt() ?? 0,
      completedToday: (json['completedToday'] as num?)?.toInt() ?? 0,
      revenueTodayVnd: (json['revenueTodayVnd'] as num?)?.toInt() ?? 0,
      avgPrepMinutes: (json['avgPrepMinutes'] as num?)?.toDouble() ?? 0,
    );
  }
}
