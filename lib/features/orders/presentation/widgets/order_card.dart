import 'package:flutter/material.dart';
import 'package:orderpulse_flutter/core/theme/app_theme.dart';
import 'package:orderpulse_flutter/core/widgets/status_badge.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';
import 'package:orderpulse_flutter/features/orders/domain/order_sla.dart';

/// High-contrast KDS order ticket card safe down to narrow 320px screens.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.now,
    this.onTap,
  });

  final Order order;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final kds = KdsColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final sla = OrderSlaEvaluator.evaluate(order, now);

    final accentColor = switch (sla.urgency) {
      SlaUrgency.overdue => kds.statusRejected,
      SlaUrgency.warning => kds.statusNew,
      _ => switch (order.status) {
          OrderStatus.newOrder => kds.statusNew,
          OrderStatus.preparing => kds.statusPreparing,
          OrderStatus.ready => kds.statusReady,
          OrderStatus.completed => kds.statusCompleted,
          OrderStatus.rejected => kds.statusRejected,
        },
    };

    final borderColor = switch (sla.urgency) {
      SlaUrgency.overdue => kds.statusRejected.withValues(alpha: 0.75),
      SlaUrgency.warning => kds.statusNew.withValues(alpha: 0.65),
      _ => kds.border,
    };

    final itemPreview = order.items
        .take(2)
        .map((item) => '${item.quantity}x ${item.name}')
        .join(', ');
    final extraCount =
        order.items.length > 2 ? ' +${order.items.length - 2} more' : '';

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: accentColor, width: 4),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      order.id,
                      style: tabularStyle(
                        textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: kds.textPrimary,
                        ),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (sla.urgency != SlaUrgency.none) ...[
                    const SizedBox(width: 6),
                    OrderSlaBadge(slaStatus: sla),
                  ],
                  const SizedBox(width: 6),
                  OrderStatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.customerName,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: kds.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatElapsedSince(order.createdAt, now),
                    style: tabularStyle(
                      textTheme.labelSmall?.copyWith(color: kds.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$itemPreview$extraCount',
                style: textTheme.bodySmall?.copyWith(color: kds.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (order.kitchenNotes != null &&
                  order.kitchenNotes!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: kds.statusNewContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: kds.statusNew.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: kds.onStatusNewContainer,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          order.kitchenNotes!,
                          style: textTheme.labelSmall?.copyWith(
                            color: kds.onStatusNewContainer,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${order.totalItemCount} item(s)${order.riderName != null ? ' • ${order.riderName}' : ''}',
                            style: tabularStyle(
                              textTheme.labelMedium?.copyWith(
                                color: kds.textSecondary,
                              ),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (order.status == OrderStatus.preparing &&
                            order.totalLineCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: kds.cardElevated,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: kds.border),
                            ),
                            child: Text(
                              '${order.preppedLineCount}/${order.totalLineCount} prepped',
                              style: tabularStyle(
                                textTheme.labelSmall?.copyWith(
                                  color: order.allItemsPrepped
                                      ? kds.onStatusReadyContainer
                                      : kds.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatVnd(order.totalAmountVnd),
                    style: tabularStyle(
                      textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: kds.brandAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
