import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:orderpulse_flutter/core/theme/app_theme.dart';
import 'package:orderpulse_flutter/features/insights/domain/shift_insights.dart';

/// CustomPainter bar chart visualizing hourly order volume across the shift.
class HourlyVolumeChart extends StatelessWidget {
  const HourlyVolumeChart({
    super.key,
    required this.buckets,
  });

  final List<HourlyOrderBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final kds = KdsColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    if (buckets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Text(
            'No hourly order data yet.',
            style: textTheme.bodySmall?.copyWith(color: kds.textSecondary),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label:
              'Hourly order volume bar chart across ${buckets.length} shift hours.',
          child: SizedBox(
            height: 138,
            child: CustomPaint(
              painter: _HourlyVolumePainter(
                buckets: buckets,
                kds: kds,
                labelStyle: tabularStyle(
                  textTheme.labelSmall?.copyWith(
                    color: kds.textSecondary,
                    fontSize: 10,
                  ),
                )!,
                valueStyle: tabularStyle(
                  textTheme.labelSmall?.copyWith(
                    color: kds.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                )!,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _LegendItem(
              color: kds.statusReady,
              label: 'Completed',
              textColor: kds.textSecondary,
            ),
            _LegendItem(
              color: kds.statusPreparing,
              label: 'Active / Other',
              textColor: kds.textSecondary,
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.textColor,
  });

  final Color color;
  final String label;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: textColor,
              ),
        ),
      ],
    );
  }
}

class _HourlyVolumePainter extends CustomPainter {
  _HourlyVolumePainter({
    required this.buckets,
    required this.kds,
    required this.labelStyle,
    required this.valueStyle,
  });

  final List<HourlyOrderBucket> buckets;
  final KdsColors kds;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  @override
  void paint(Canvas canvas, Size size) {
    const topPadding = 22.0;
    const bottomPadding = 26.0;
    const leftPadding = 8.0;
    const rightPadding = 8.0;

    final chartHeight = size.height - topPadding - bottomPadding;
    final chartWidth = size.width - leftPadding - rightPadding;
    if (chartHeight <= 0 || chartWidth <= 0 || buckets.isEmpty) return;

    final maxCount = buckets.fold<int>(
      1,
      (best, b) => math.max(best, b.totalCount),
    );

    final gridPaint = Paint()
      ..color = kds.border.withValues(alpha: 0.7)
      ..strokeWidth = 1;

    for (var step = 0; step <= 3; step++) {
      final y = topPadding + (chartHeight * step / 3);
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );
    }

    final slotWidth = chartWidth / buckets.length;
    final barWidth = math.min(34.0, slotWidth * 0.54);

    final completedPaint = Paint()..color = kds.statusReady;
    final otherPaint = Paint()..color = kds.statusPreparing;

    for (var i = 0; i < buckets.length; i++) {
      final bucket = buckets[i];
      final centerX = leftPadding + slotWidth * (i + 0.5);
      final left = centerX - barWidth / 2;

      final totalRatio = bucket.totalCount / maxCount;
      final totalBarHeight = math.max(4.0, chartHeight * totalRatio);
      final topY = topPadding + chartHeight - totalBarHeight;
      final baseBottom = topPadding + chartHeight;

      final fullRect = RRect.fromRectAndCorners(
        Rect.fromLTRB(left, topY, left + barWidth, baseBottom),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      );
      canvas.drawRRect(fullRect, otherPaint);

      if (bucket.completedCount > 0) {
        final completedHeight =
            totalBarHeight * (bucket.completedCount / bucket.totalCount);
        final completedTop = baseBottom - completedHeight;
        final isAllCompleted = bucket.completedCount == bucket.totalCount;
        final completedRect = RRect.fromRectAndCorners(
          Rect.fromLTRB(left, completedTop, left + barWidth, baseBottom),
          topLeft: isAllCompleted ? const Radius.circular(6) : Radius.zero,
          topRight: isAllCompleted ? const Radius.circular(6) : Radius.zero,
        );
        canvas.drawRRect(completedRect, completedPaint);
      }

      final countPainter = TextPainter(
        text: TextSpan(text: '${bucket.totalCount}', style: valueStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      countPainter.paint(
        canvas,
        Offset(centerX - countPainter.width / 2, topY - countPainter.height - 3),
      );

      final hourPainter = TextPainter(
        text: TextSpan(text: bucket.hourLabel, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      hourPainter.paint(
        canvas,
        Offset(centerX - hourPainter.width / 2, baseBottom + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HourlyVolumePainter oldDelegate) {
    return oldDelegate.buckets != buckets || oldDelegate.kds != kds;
  }
}
