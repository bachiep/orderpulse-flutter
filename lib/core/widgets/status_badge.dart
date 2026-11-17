import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';

final NumberFormat _vndFormat = NumberFormat.decimalPattern('vi_VN');

/// Formats integer VND amounts cleanly without floating-point rounding drift.
String formatVnd(int amountVnd) => '${_vndFormat.format(amountVnd)} đ';

/// Formats a compact relative timestamp against [now].
String formatElapsedSince(DateTime timestamp, DateTime now) {
  final diff = now.difference(timestamp);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/// Color-coded Material 3 pill badge representing an [OrderStatus].
class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({
    super.key,
    required this.status,
  });

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final (bg, fg, icon) = _paletteFor(status, brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
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

  (Color, Color, IconData) _paletteFor(
    OrderStatus status,
    Brightness brightness,
  ) {
    final isDark = brightness == Brightness.dark;
    return switch (status) {
      OrderStatus.newOrder => (
          isDark ? const Color(0xFF0C4A6E) : const Color(0xFFE0F2FE),
          isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1),
          Icons.notifications_active_outlined,
        ),
      OrderStatus.preparing => (
          isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
          isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
          Icons.local_fire_department_outlined,
        ),
      OrderStatus.ready => (
          isDark ? const Color(0xFF312E81) : const Color(0xFFE0E7FF),
          isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA),
          Icons.inventory_2_outlined,
        ),
      OrderStatus.completed => (
          isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
          isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
          Icons.check_circle_outline,
        ),
      OrderStatus.rejected => (
          isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
          isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
          Icons.cancel_outlined,
        ),
    };
  }
}
