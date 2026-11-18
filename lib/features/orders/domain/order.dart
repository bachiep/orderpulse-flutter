import 'package:equatable/equatable.dart';

/// Lifecycle states of a merchant order in the kitchen dispatch workflow.
enum OrderStatus {
  newOrder,
  preparing,
  ready,
  completed,
  rejected;

  /// Canonical API wire value.
  String get apiValue => switch (this) {
        OrderStatus.newOrder => 'NEW',
        OrderStatus.preparing => 'PREPARING',
        OrderStatus.ready => 'READY',
        OrderStatus.completed => 'COMPLETED',
        OrderStatus.rejected => 'REJECTED',
      };

  /// Human-readable display label.
  String get label => switch (this) {
        OrderStatus.newOrder => 'New',
        OrderStatus.preparing => 'Preparing',
        OrderStatus.ready => 'Ready',
        OrderStatus.completed => 'Completed',
        OrderStatus.rejected => 'Rejected',
      };

  bool get isActive =>
      this == OrderStatus.newOrder ||
      this == OrderStatus.preparing ||
      this == OrderStatus.ready;

  /// Parses an API status string, defaulting safely to [OrderStatus.newOrder].
  static OrderStatus fromApi(String raw) {
    return switch (raw.trim().toUpperCase()) {
      'NEW' => OrderStatus.newOrder,
      'PREPARING' => OrderStatus.preparing,
      'READY' => OrderStatus.ready,
      'COMPLETED' => OrderStatus.completed,
      'REJECTED' => OrderStatus.rejected,
      _ => OrderStatus.newOrder,
    };
  }
}

/// Filter tabs displayed above the merchant order board.
enum OrderFilterTab {
  all,
  newOrder,
  preparing,
  ready,
  completed,
  rejected;

  String get label => switch (this) {
        OrderFilterTab.all => 'All',
        OrderFilterTab.newOrder => 'New',
        OrderFilterTab.preparing => 'Preparing',
        OrderFilterTab.ready => 'Ready',
        OrderFilterTab.completed => 'Completed',
        OrderFilterTab.rejected => 'Rejected',
      };

  OrderStatus? get statusFilter => switch (this) {
        OrderFilterTab.all => null,
        OrderFilterTab.newOrder => OrderStatus.newOrder,
        OrderFilterTab.preparing => OrderStatus.preparing,
        OrderFilterTab.ready => OrderStatus.ready,
        OrderFilterTab.completed => OrderStatus.completed,
        OrderFilterTab.rejected => OrderStatus.rejected,
      };
}

/// Individual line item within an order ticket.
class OrderItem extends Equatable {
  const OrderItem({
    required this.name,
    required this.quantity,
    required this.unitPriceVnd,
    this.note,
    this.isPrepped = false,
  });

  final String name;
  final int quantity;
  final int unitPriceVnd;
  final String? note;
  final bool isPrepped;

  int get lineTotalVnd => quantity * unitPriceVnd;

  OrderItem copyWith({
    bool? isPrepped,
  }) {
    return OrderItem(
      name: name,
      quantity: quantity,
      unitPriceVnd: unitPriceVnd,
      note: note,
      isPrepped: isPrepped ?? this.isPrepped,
    );
  }

  @override
  List<Object?> get props => [name, quantity, unitPriceVnd, note, isPrepped];
}

/// Immutable O2O merchant order aggregate.
class Order extends Equatable {
  const Order({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.items,
    required this.totalAmountVnd,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.kitchenNotes,
    this.riderName,
    this.riderPlate,
    this.riderPhone,
    this.riderVehicle,
    this.riderEtaMinutes,
    this.pickupCode,
    this.rejectionReason,
    this.targetPrepMinutes = 15,
    this.acceptedAt,
    this.readyAt,
    this.completedAt,
  });

  final String id;
  final String customerName;
  final String customerPhone;
  final List<OrderItem> items;
  final int totalAmountVnd;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? kitchenNotes;
  final String? riderName;
  final String? riderPlate;
  final String? riderPhone;
  final String? riderVehicle;
  final int? riderEtaMinutes;
  final String? pickupCode;
  final String? rejectionReason;
  final int targetPrepMinutes;
  final DateTime? acceptedAt;
  final DateTime? readyAt;
  final DateTime? completedAt;

  int get totalItemCount =>
      items.fold<int>(0, (sum, item) => sum + item.quantity);

  int get preppedLineCount => items.where((item) => item.isPrepped).length;

  int get totalLineCount => items.length;

  bool get allItemsPrepped =>
      items.isNotEmpty && items.every((item) => item.isPrepped);

  DateTime get slaDeadline =>
      createdAt.add(Duration(minutes: targetPrepMinutes));

  String get resolvedPickupCode {
    if (pickupCode != null && pickupCode!.trim().isNotEmpty) {
      return pickupCode!;
    }
    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    return 'PK-${digits.isEmpty ? id : digits}';
  }

  Order toggleItemPrepped(int index, {bool? isPrepped}) {
    if (index < 0 || index >= items.length) return this;
    final nextItems = List<OrderItem>.from(items);
    final current = nextItems[index];
    nextItems[index] = current.copyWith(isPrepped: isPrepped ?? !current.isPrepped);
    return copyWith(items: nextItems);
  }

  Order copyWith({
    List<OrderItem>? items,
    OrderStatus? status,
    DateTime? updatedAt,
    String? riderName,
    String? riderPlate,
    String? riderPhone,
    String? riderVehicle,
    int? riderEtaMinutes,
    String? pickupCode,
    String? rejectionReason,
    int? targetPrepMinutes,
    DateTime? acceptedAt,
    DateTime? readyAt,
    DateTime? completedAt,
  }) {
    return Order(
      id: id,
      customerName: customerName,
      customerPhone: customerPhone,
      items: items ?? this.items,
      totalAmountVnd: totalAmountVnd,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      kitchenNotes: kitchenNotes,
      riderName: riderName ?? this.riderName,
      riderPlate: riderPlate ?? this.riderPlate,
      riderPhone: riderPhone ?? this.riderPhone,
      riderVehicle: riderVehicle ?? this.riderVehicle,
      riderEtaMinutes: riderEtaMinutes ?? this.riderEtaMinutes,
      pickupCode: pickupCode ?? this.pickupCode,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      targetPrepMinutes: targetPrepMinutes ?? this.targetPrepMinutes,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      readyAt: readyAt ?? this.readyAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        customerName,
        customerPhone,
        items,
        totalAmountVnd,
        status,
        createdAt,
        updatedAt,
        kitchenNotes,
        riderName,
        riderPlate,
        riderPhone,
        riderVehicle,
        riderEtaMinutes,
        pickupCode,
        rejectionReason,
        targetPrepMinutes,
        acceptedAt,
        readyAt,
        completedAt,
      ];
}

/// Paginated slice of orders returned by [OrderRepository.fetchOrders].
class OrderPage extends Equatable {
  const OrderPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.hasMore,
    required this.totalCount,
  });

  final List<Order> items;
  final int page;
  final int pageSize;
  final bool hasMore;
  final int totalCount;

  @override
  List<Object?> get props => [items, page, pageSize, hasMore, totalCount];
}

/// Aggregate KPI metrics for the active merchant shift.
class MerchantShiftStats extends Equatable {
  const MerchantShiftStats({
    required this.activeCount,
    required this.completedToday,
    required this.revenueTodayVnd,
    required this.avgPrepMinutes,
  });

  final int activeCount;
  final int completedToday;
  final int revenueTodayVnd;
  final double avgPrepMinutes;

  @override
  List<Object?> get props => [
        activeCount,
        completedToday,
        revenueTodayVnd,
        avgPrepMinutes,
      ];
}
