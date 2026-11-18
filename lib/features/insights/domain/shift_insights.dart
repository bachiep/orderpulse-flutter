import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';
import 'package:orderpulse_flutter/features/orders/domain/order_sla.dart';

/// Order volume and completed revenue aggregated into one clock hour bucket.
class HourlyOrderBucket extends Equatable {
  const HourlyOrderBucket({
    required this.hour,
    required this.totalCount,
    required this.completedCount,
    required this.activeCount,
    required this.revenueVnd,
  });

  final int hour;
  final int totalCount;
  final int completedCount;
  final int activeCount;
  final int revenueVnd;

  String get hourLabel => '${hour.toString().padLeft(2, '0')}:00';

  @override
  List<Object?> get props => [
        hour,
        totalCount,
        completedCount,
        activeCount,
        revenueVnd,
      ];
}

/// Share of orders in a single [OrderStatus] for the distribution chart.
class StatusMixSlice extends Equatable {
  const StatusMixSlice({
    required this.status,
    required this.count,
    required this.share,
  });

  final OrderStatus status;
  final int count;
  final double share;

  @override
  List<Object?> get props => [status, count, share];
}

/// Top-selling menu dish aggregated dynamically from the active shift orders.
class TopDishMetric extends Equatable {
  const TopDishMetric({
    required this.dishName,
    required this.quantitySold,
    required this.revenueVnd,
  });

  final String dishName;
  final int quantitySold;
  final int revenueVnd;

  @override
  List<Object?> get props => [dishName, quantitySold, revenueVnd];
}

/// Complete Shift Insights snapshot derived deterministically from a list of orders.
class ShiftInsights extends Equatable {
  const ShiftInsights({
    required this.totalOrders,
    required this.completedOrders,
    required this.grossRevenueVnd,
    required this.avgPrepMinutes,
    required this.onTimeSlaPercent,
    required this.hourlyBuckets,
    required this.statusMix,
    required this.topDishes,
  });

  final int totalOrders;
  final int completedOrders;
  final int grossRevenueVnd;
  final double avgPrepMinutes;
  final double onTimeSlaPercent;
  final List<HourlyOrderBucket> hourlyBuckets;
  final List<StatusMixSlice> statusMix;
  final List<TopDishMetric> topDishes;

  @override
  List<Object?> get props => [
        totalOrders,
        completedOrders,
        grossRevenueVnd,
        avgPrepMinutes,
        onTimeSlaPercent,
        hourlyBuckets,
        statusMix,
        topDishes,
      ];
}

/// Pure domain aggregator computing KPI metrics, hourly buckets, status mix, and top dishes.
abstract final class ShiftInsightsCalculator {
  static ShiftInsights compute(List<Order> orders, DateTime now) {
    if (orders.isEmpty) {
      return ShiftInsights(
        totalOrders: 0,
        completedOrders: 0,
        grossRevenueVnd: 0,
        avgPrepMinutes: 0,
        onTimeSlaPercent: 0,
        hourlyBuckets: const [],
        statusMix: OrderStatus.values
            .map((s) => StatusMixSlice(status: s, count: 0, share: 0))
            .toList(growable: false),
        topDishes: const [],
      );
    }

    var completedOrders = 0;
    var grossRevenueVnd = 0;

    final prepDurationsMinutes = <double>[];
    var slaEvaluatedCount = 0;
    var slaOnTimeCount = 0;

    final hourGroups = <int, List<Order>>{};
    final statusCounts = <OrderStatus, int>{
      for (final status in OrderStatus.values) status: 0,
    };
    final dishQty = <String, int>{};
    final dishRevenue = <String, int>{};

    for (final order in orders) {
      statusCounts[order.status] = (statusCounts[order.status] ?? 0) + 1;
      hourGroups.putIfAbsent(order.createdAt.hour, () => []).add(order);

      if (order.status == OrderStatus.completed) {
        completedOrders += 1;
        grossRevenueVnd += order.totalAmountVnd;
      }

      if (order.status == OrderStatus.ready ||
          order.status == OrderStatus.completed) {
        final finish = order.readyAt ?? order.completedAt ?? order.updatedAt;
        final prepSeconds = finish.difference(order.createdAt).inSeconds;
        final prepMins = math.max(1.0, prepSeconds / 60.0);
        prepDurationsMinutes.add(prepMins);

        slaEvaluatedCount += 1;
        if (finish.difference(order.createdAt) <=
            Duration(minutes: order.targetPrepMinutes)) {
          slaOnTimeCount += 1;
        }
      } else if (order.status.isActive) {
        slaEvaluatedCount += 1;
        final sla = OrderSlaEvaluator.evaluate(order, now);
        if (sla.urgency != SlaUrgency.overdue) {
          slaOnTimeCount += 1;
        }
      }

      if (order.status != OrderStatus.rejected) {
        for (final item in order.items) {
          dishQty[item.name] = (dishQty[item.name] ?? 0) + item.quantity;
          dishRevenue[item.name] =
              (dishRevenue[item.name] ?? 0) + item.lineTotalVnd;
        }
      }
    }

    final avgPrepMinutes = prepDurationsMinutes.isEmpty
        ? 0.0
        : prepDurationsMinutes.reduce((a, b) => a + b) /
            prepDurationsMinutes.length;

    final onTimeSlaPercent = slaEvaluatedCount == 0
        ? 0.0
        : (slaOnTimeCount / slaEvaluatedCount) * 100.0;

    final sortedHours = hourGroups.keys.toList()..sort();
    final hourlyBuckets = sortedHours.map((hour) {
      final bucketOrders = hourGroups[hour]!;
      var completedInHour = 0;
      var activeInHour = 0;
      var revenueInHour = 0;
      for (final o in bucketOrders) {
        if (o.status == OrderStatus.completed) {
          completedInHour += 1;
          revenueInHour += o.totalAmountVnd;
        } else if (o.status.isActive) {
          activeInHour += 1;
        }
      }
      return HourlyOrderBucket(
        hour: hour,
        totalCount: bucketOrders.length,
        completedCount: completedInHour,
        activeCount: activeInHour,
        revenueVnd: revenueInHour,
      );
    }).toList(growable: false);

    final statusMix = OrderStatus.values.map((status) {
      final count = statusCounts[status] ?? 0;
      return StatusMixSlice(
        status: status,
        count: count,
        share: orders.isEmpty ? 0.0 : count / orders.length,
      );
    }).toList(growable: false);

    final topDishes = dishQty.keys.map((name) {
      return TopDishMetric(
        dishName: name,
        quantitySold: dishQty[name] ?? 0,
        revenueVnd: dishRevenue[name] ?? 0,
      );
    }).toList()
      ..sort((a, b) {
        final byQty = b.quantitySold.compareTo(a.quantitySold);
        if (byQty != 0) return byQty;
        final byRev = b.revenueVnd.compareTo(a.revenueVnd);
        if (byRev != 0) return byRev;
        return a.dishName.compareTo(b.dishName);
      });

    return ShiftInsights(
      totalOrders: orders.length,
      completedOrders: completedOrders,
      grossRevenueVnd: grossRevenueVnd,
      avgPrepMinutes: avgPrepMinutes,
      onTimeSlaPercent: onTimeSlaPercent,
      hourlyBuckets: hourlyBuckets,
      statusMix: statusMix,
      topDishes: topDishes.take(5).toList(growable: false),
    );
  }
}
