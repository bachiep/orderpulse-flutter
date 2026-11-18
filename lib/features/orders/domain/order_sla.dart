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
}
