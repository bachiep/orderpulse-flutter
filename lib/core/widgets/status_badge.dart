import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:orderpulse_flutter/core/theme/app_theme.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';
import 'package:orderpulse_flutter/features/orders/domain/order_sla.dart';

final NumberFormat _vndFormat = NumberFormat.decimalPattern('vi_VN');
final DateFormat _clockFormat = DateFormat('HH:mm');

/// Formats integer VND amounts cleanly without floating-point rounding drift.
String formatVnd(int amountVnd) => '${_vndFormat.format(amountVnd)} đ';

/// Formats a compact 24-hour clock timestamp (`HH:mm`).
String formatClockTime(DateTime timestamp) => _clockFormat.format(timestamp);

/// Formats a compact relative timestamp against [now].
String formatElapsedSince(DateTime timestamp, DateTime now) {
  final diff = now.difference(timestamp);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/// Color-coded high-contrast KDS pill badge representing an [OrderStatus].
class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({
    super.key,
    required this.status,
  });

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final kds = KdsColors.of(context);
    final (bg, fg, border, icon) = switch (status) {
      OrderStatus.newOrder => (
          kds.statusNewContainer,
          kds.onStatusNewContainer,
          kds.statusNew,
          Icons.notifications_active_outlined,
        ),
      OrderStatus.preparing => (
          kds.statusPreparingContainer,
          kds.onStatusPreparingContainer,
          kds.statusPreparing,
          Icons.local_fire_department_outlined,
        ),
      OrderStatus.ready => (
          kds.statusReadyContainer,
          kds.onStatusReadyContainer,
          kds.statusReady,
          Icons.inventory_2_outlined,
        ),
      OrderStatus.completed => (
          kds.statusCompletedContainer,
          kds.onStatusCompletedContainer,
          kds.statusCompleted,
          Icons.check_circle_outline,
        ),
      OrderStatus.rejected => (
          kds.statusRejectedContainer,
          kds.onStatusRejectedContainer,
          kds.statusRejected,
          Icons.cancel_outlined,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border.withValues(alpha: 0.65), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

/// High-contrast SLA countdown badge (`11m left` -> `3m left` -> `+4m OVERDUE`).
class OrderSlaBadge extends StatelessWidget {
  const OrderSlaBadge({
    super.key,
    required this.slaStatus,
  });

  final OrderSlaStatus slaStatus;

  @override
  Widget build(BuildContext context) {
    if (slaStatus.urgency == SlaUrgency.none || slaStatus.label.isEmpty) {
      return const SizedBox.shrink();
    }

    final kds = KdsColors.of(context);
    final (bg, fg, border, icon) = switch (slaStatus.urgency) {
      SlaUrgency.healthy => (
          kds.statusReadyContainer,
          kds.onStatusReadyContainer,
          kds.statusReady,
          Icons.timer_outlined,
        ),
      SlaUrgency.warning => (
          kds.statusNewContainer,
          kds.onStatusNewContainer,
          kds.statusNew,
          Icons.timelapse_rounded,
        ),
      SlaUrgency.overdue => (
          kds.statusRejectedContainer,
          kds.onStatusRejectedContainer,
          kds.statusRejected,
          Icons.warning_amber_rounded,
        ),
      SlaUrgency.none => (
          Colors.transparent,
          kds.textSecondary,
          kds.border,
          Icons.timer_outlined,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border.withValues(alpha: 0.7), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            slaStatus.label,
            style: tabularStyle(
              Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
