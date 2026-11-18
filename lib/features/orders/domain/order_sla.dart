import 'package:equatable/equatable.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';

/// Urgency bands for an active kitchen ticket relative to its prep SLA target.
enum SlaUrgency {
  healthy,
  warning,
  overdue,
  none;

  bool get isUrgent => this == SlaUrgency.warning || this == SlaUrgency.overdue;
}

/// Evaluated SLA countdown snapshot for an [Order] at a point in time.
class OrderSlaStatus extends Equatable {
  const OrderSlaStatus({
    required this.urgency,
    required this.label,
    required this.remaining,
  });

  final SlaUrgency urgency;
  final String label;
  final Duration remaining;

  @override
  List<Object?> get props => [urgency, label, remaining];
}

/// Pure domain evaluator for prep SLA countdowns driven by an injected [AppClock].
abstract final class OrderSlaEvaluator {
  static const Duration warningThreshold = Duration(minutes: 5);

  /// Evaluates active order prep SLA countdown (`11m left` -> `3m left` -> `+4m OVERDUE`).
  static OrderSlaStatus evaluate(Order order, DateTime now) {
    if (!order.status.isActive) {
      return const OrderSlaStatus(
        urgency: SlaUrgency.none,
        label: '',
        remaining: Duration.zero,
      );
    }

    final remaining = order.slaDeadline.difference(now);
    if (remaining.isNegative) {
      final overdueSeconds = -remaining.inSeconds;
      final overdueMinutes =
          overdueSeconds <= 0 ? 1 : ((overdueSeconds + 59) ~/ 60);
      return OrderSlaStatus(
        urgency: SlaUrgency.overdue,
        label: '+${overdueMinutes}m OVERDUE',
        remaining: remaining,
      );
    }

    final minutesLeft =
        remaining.inSeconds <= 0 ? 0 : ((remaining.inSeconds + 59) ~/ 60);
    final urgency = remaining <= warningThreshold
        ? SlaUrgency.warning
        : SlaUrgency.healthy;

    return OrderSlaStatus(
      urgency: urgency,
      label: '${minutesLeft}m left',
      remaining: remaining,
    );
  }

  /// Returns true when an active order is either overdue or within the warning SLA band.
  static bool isUrgentOrder(Order order, DateTime now) {
    return evaluate(order, now).urgency.isUrgent;
  }

  /// Compares two orders so overdue & earliest-deadline active tickets rise to the top.
  static int compareBySlaUrgency(Order a, Order b, DateTime now) {
    final aActive = a.status.isActive;
    final bActive = b.status.isActive;
    if (aActive != bActive) {
      return aActive ? -1 : 1;
    }

    if (aActive && bActive) {
      final slaA = evaluate(a, now);
      final slaB = evaluate(b, now);
      final rankCompare =
          _urgencyRank(slaA.urgency).compareTo(_urgencyRank(slaB.urgency));
      if (rankCompare != 0) return rankCompare;

      final deadlineCompare = a.slaDeadline.compareTo(b.slaDeadline);
      if (deadlineCompare != 0) return deadlineCompare;
    }

    final createdCompare = b.createdAt.compareTo(a.createdAt);
    if (createdCompare != 0) return createdCompare;
    return a.id.compareTo(b.id);
  }

  /// Applies optional urgent-only filtering and SLA urgency sorting to [orders].
  static List<Order> applyBoardView(
    List<Order> orders, {
    required DateTime now,
    bool urgentOnly = false,
    OrderSortMode sortMode = OrderSortMode.newestFirst,
  }) {
    final filtered = urgentOnly
        ? orders.where((o) => isUrgentOrder(o, now)).toList()
        : List<Order>.from(orders);

    if (sortMode == OrderSortMode.slaUrgencyFirst) {
      filtered.sort((a, b) => compareBySlaUrgency(a, b, now));
    }
    return filtered;
  }

  static int _urgencyRank(SlaUrgency urgency) {
    return switch (urgency) {
      SlaUrgency.overdue => 0,
      SlaUrgency.warning => 1,
      SlaUrgency.healthy => 2,
      SlaUrgency.none => 3,
    };
  }
}
