import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:orderpulse_flutter/core/theme/app_theme.dart';
import 'package:orderpulse_flutter/features/insights/domain/shift_insights.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';

/// CustomPainter donut ring and semantic breakdown legend for shift order statuses.
class StatusDistributionChart extends StatelessWidget {
  const StatusDistributionChart({
    super.key,
    required this.slices,
    required this.totalOrders,
  });

  final List<StatusMixSlice> slices;
  final int totalOrders;

  @override
  Widget build(BuildContext context) {
    final kds = KdsColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    Color colorForStatus(OrderStatus status) => switch (status) {
          OrderStatus.newOrder => kds.statusNew,
          OrderStatus.preparing => kds.statusPreparing,
          OrderStatus.ready => kds.statusReady,
          OrderStatus.completed => kds.statusCompleted,
          OrderStatus.rejected => kds.statusRejected,
        };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          label: 'Order status distribution across $totalOrders tickets.',
          child: SizedBox(
            width: 98,
            height: 98,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(98, 98),
                  painter: _StatusDonutPainter(
                    slices: slices,
                    colorForStatus: colorForStatus,
                    trackColor: kds.cardElevated,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$totalOrders',
                      style: tabularStyle(
                        textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: kds.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      'Orders',
                      style: textTheme.labelSmall?.copyWith(
                        color: kds.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: slices.map((slice) {
              final pct = (slice.share * 100).round();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colorForStatus(slice.status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        slice.status.label,
                        style: textTheme.bodySmall?.copyWith(
                          color: kds.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${slice.count} ($pct%)',
                      style: tabularStyle(
                        textTheme.labelSmall?.copyWith(
                          color: kds.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _StatusDonutPainter extends CustomPainter {
  _StatusDonutPainter({
    required this.slices,
    required this.colorForStatus,
    required this.trackColor,
  });

  final List<StatusMixSlice> slices;
  final Color Function(OrderStatus status) colorForStatus;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 14.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, trackPaint);

    final nonZero = slices.where((s) => s.count > 0).toList(growable: false);
    if (nonZero.isEmpty) return;

    final gap = nonZero.length > 1 ? 0.04 : 0.0;
    var startAngle = -math.pi / 2;

    for (final slice in nonZero) {
      final fullSweep = slice.share * math.pi * 2;
      final sweep = math.max(0.02, fullSweep - gap);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = colorForStatus(slice.status);

      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += fullSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _StatusDonutPainter oldDelegate) {
    return oldDelegate.slices != slices || oldDelegate.trackColor != trackColor;
  }
}
