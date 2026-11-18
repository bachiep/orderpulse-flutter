import 'package:flutter/material.dart';
import 'package:orderpulse_flutter/core/theme/app_theme.dart';
import 'package:orderpulse_flutter/core/widgets/status_badge.dart';
import 'package:orderpulse_flutter/features/insights/domain/shift_insights.dart';
import 'package:orderpulse_flutter/features/insights/presentation/widgets/hourly_volume_chart.dart';
import 'package:orderpulse_flutter/features/insights/presentation/widgets/status_distribution_chart.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';

/// Shift Insights analytics tab rendering KPIs, CustomPainter charts, and Top 5 Dishes.
class ShiftInsightsView extends StatelessWidget {
  const ShiftInsightsView({
    super.key,
    required this.orders,
    required this.now,
    this.onRefresh,
  });

  final List<Order> orders;
  final DateTime now;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final kds = KdsColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final insights = ShiftInsightsCalculator.compute(orders, now);

    final slaColor = insights.onTimeSlaPercent >= 85
        ? kds.statusReady
        : insights.onTimeSlaPercent >= 65
            ? kds.statusNew
            : kds.statusRejected;

    final maxDishQty = insights.topDishes.isEmpty
        ? 1
        : insights.topDishes.first.quantitySold;

    final content = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Row(
          children: [
            Expanded(
              child: _InsightKpiCard(
                label: 'Completed Orders',
                value: '${insights.completedOrders}',
                icon: Icons.check_circle_outline_rounded,
                accentColor: kds.statusReady,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _InsightKpiCard(
                label: 'Gross Revenue',
                value: formatVnd(insights.grossRevenueVnd),
                icon: Icons.payments_outlined,
                accentColor: kds.brandAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _InsightKpiCard(
                label: 'Avg Prep Time',
                value: '${insights.avgPrepMinutes.toStringAsFixed(1)}m',
                icon: Icons.timer_outlined,
                accentColor: kds.statusPreparing,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _InsightKpiCard(
                label: 'On-Time SLA %',
                value: '${insights.onTimeSlaPercent.toStringAsFixed(1)}%',
                icon: Icons.speed_rounded,
                accentColor: slaColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bar_chart_rounded, size: 18, color: kds.brandAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hourly Order Volume',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: kds.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Shift ticket throughput by hour',
                  style: textTheme.bodySmall?.copyWith(color: kds.textSecondary),
                ),
                const SizedBox(height: 8),
                HourlyVolumeChart(buckets: insights.hourlyBuckets),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.pie_chart_outline_rounded,
                      size: 18,
                      color: kds.statusPreparing,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Status Distribution',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: kds.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                StatusDistributionChart(
                  slices: insights.statusMix,
                  totalOrders: insights.totalOrders,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.restaurant_menu_rounded,
                      size: 18,
                      color: kds.statusNew,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Top 5 Dishes',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: kds.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      'Qty & Revenue',
                      style: textTheme.labelSmall?.copyWith(
                        color: kds.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (insights.topDishes.isEmpty)
                  Text(
                    'No dish data recorded for this shift.',
                    style: textTheme.bodySmall?.copyWith(
                      color: kds.textSecondary,
                    ),
                  )
                else
                  ...insights.topDishes.asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final dish = entry.value;
                    final progress = dish.quantitySold / maxDishQty;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: rank == insights.topDishes.length ? 0 : 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: rank == 1
                                      ? kds.statusNewContainer
                                      : kds.cardElevated,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: rank == 1
                                        ? kds.statusNew.withValues(alpha: 0.6)
                                        : kds.border,
                                  ),
                                ),
                                child: Text(
                                  '#$rank',
                                  style: tabularStyle(
                                    textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: rank == 1
                                          ? kds.onStatusNewContainer
                                          : kds.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  dish.dishName,
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: kds.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${dish.quantitySold}x • ${formatVnd(dish.revenueVnd)}',
                                style: tabularStyle(
                                  textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: kds.brandAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progress.clamp(0.05, 1.0),
                              minHeight: 5,
                              backgroundColor: kds.cardElevated,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                rank == 1 ? kds.statusNew : kds.brandAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );

    if (onRefresh != null) {
      return RefreshIndicator(onRefresh: onRefresh!, child: content);
    }
    return content;
  }
}

class _InsightKpiCard extends StatelessWidget {
  const _InsightKpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final kds = KdsColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: accentColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: textTheme.labelSmall?.copyWith(
                      color: kds.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: tabularStyle(
                textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: kds.textPrimary,
                ),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
