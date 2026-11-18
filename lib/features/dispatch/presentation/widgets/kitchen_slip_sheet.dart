import 'package:flutter/material.dart';
import 'package:orderpulse_flutter/core/theme/app_theme.dart';
import 'package:orderpulse_flutter/core/widgets/status_badge.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';
import 'package:orderpulse_flutter/features/orders/domain/order_sla.dart';

/// Monospace 80mm thermal kitchen slip preview modal sheet.
class KitchenSlipSheet extends StatelessWidget {
  const KitchenSlipSheet({
    super.key,
    required this.order,
    required this.now,
    this.merchantBranch = 'District 1 • Demo Kitchen',
  });

  final Order order;
  final DateTime now;
  final String merchantBranch;

  static Future<void> show(
    BuildContext context, {
    required Order order,
    required DateTime now,
    String merchantBranch = 'District 1 • Demo Kitchen',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => KitchenSlipSheet(
        order: order,
        now: now,
        merchantBranch: merchantBranch,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kds = KdsColors.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.84;
    final sla = OrderSlaEvaluator.evaluate(order, now);

    const paperBg = Color(0xFFFAF8F2);
    const paperInk = Color(0xFF111827);
    const paperMuted = Color(0xFF4B5563);
    const paperDivider = Color(0xFFD1D5DB);

    const monoBase = TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: ['Roboto'],
      fontSize: 12,
      height: 1.32,
      color: paperInk,
      fontFeatures: [FontFeature.tabularFigures()],
    );

    final channelLabel =
        (order.riderName != null || order.pickupCode != null)
            ? 'O2O Delivery • ${order.resolvedPickupCode}'
            : 'Pickup ${order.resolvedPickupCode}';
    final slaText = sla.urgency == SlaUrgency.none
        ? 'TARGET ${order.targetPrepMinutes}m'
        : sla.label;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, size: 20, color: kds.brandAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '80mm Thermal Kitchen Slip',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: kds.textPrimary,
                        ),
                  ),
                ),
                Text(
                  '80mm • ESC/POS',
                  style: tabularStyle(
                    Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: kds.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: paperBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: paperDivider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'ORDERPULSE KITCHEN',
                            textAlign: TextAlign.center,
                            style: monoBase.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            merchantBranch,
                            textAlign: TextAlign.center,
                            style: monoBase.copyWith(
                              fontSize: 11,
                              color: paperMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '*** KITCHEN PREP SLIP ***',
                            textAlign: TextAlign.center,
                            style: monoBase.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const _SlipDivider(color: paperMuted),
                          _SlipMetaRow(
                            left: 'ORDER: ${order.id}',
                            right: 'SLA: $slaText',
                            style: monoBase.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            rightColor: sla.urgency == SlaUrgency.overdue
                                ? const Color(0xFFB91C1C)
                                : paperInk,
                          ),
                          const SizedBox(height: 2),
                          Text('CHANNEL: $channelLabel', style: monoBase),
                          Text(
                            'CUSTOMER: ${order.customerName}',
                            style: monoBase,
                          ),
                          Text(
                            'STATUS: ${order.status.apiValue}',
                            style: monoBase,
                          ),
                          const _SlipDivider(color: paperMuted),
                          _SlipMetaRow(
                            left: 'PLACED: ${formatClockTime(order.createdAt)}',
                            right:
                                'SLA DUE: ${formatClockTime(order.slaDeadline)}',
                            style: monoBase.copyWith(
                              fontSize: 11,
                              color: paperMuted,
                            ),
                          ),
                          _SlipMetaRow(
                            left: order.acceptedAt != null
                                ? 'ACCEPTED: ${formatClockTime(order.acceptedAt!)}'
                                : 'ACCEPTED: --:--',
                            right: 'PRINTED: ${formatClockTime(now)}',
                            style: monoBase.copyWith(
                              fontSize: 11,
                              color: paperMuted,
                            ),
                          ),
                          if (order.kitchenNotes != null &&
                              order.kitchenNotes!.trim().isNotEmpty) ...[
                            const _SlipDivider(color: paperMuted),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                border: Border.all(
                                  color: const Color(0xFFD97706),
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'KITCHEN NOTE: ${order.kitchenNotes!}',
                                style: monoBase.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF78350F),
                                ),
                              ),
                            ),
                          ],
                          const _SlipDivider(color: paperMuted),
                          Text(
                            'QTY  ITEM                        AMOUNT',
                            style: monoBase.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: paperMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...order.items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${item.quantity}x ${item.name}',
                                          style: monoBase.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        formatVnd(item.lineTotalVnd),
                                        style: monoBase.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 14),
                                    child: Text(
                                      [
                                        if (item.note != null &&
                                            item.note!.trim().isNotEmpty)
                                          '* ${item.note!.trim()}',
                                        item.isPrepped
                                            ? '[PREPPED]'
                                            : '[PENDING]',
                                      ].join(' '),
                                      style: monoBase.copyWith(
                                        fontSize: 11,
                                        color: paperMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const _SlipDivider(color: paperMuted),
                          _SlipMetaRow(
                            left: 'ITEMS: ${order.totalItemCount}',
                            right: 'TOTAL: ${formatVnd(order.totalAmountVnd)}',
                            style: monoBase.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '--- END OF KITCHEN TICKET ---',
                            textAlign: TextAlign.center,
                            style: monoBase.copyWith(
                              fontSize: 11,
                              color: paperMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      Navigator.of(context).pop();
                      messenger?.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Kitchen slip queued for ${order.id} (80mm).',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('Print Slip'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SlipDivider extends StatelessWidget {
  const _SlipDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        '----------------------------------------',
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TextStyle(
          fontFamily: 'monospace',
          fontFamilyFallback: const ['Roboto'],
          fontSize: 11,
          color: color.withValues(alpha: 0.7),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _SlipMetaRow extends StatelessWidget {
  const _SlipMetaRow({
    required this.left,
    required this.right,
    required this.style,
    this.rightColor,
  });

  final String left;
  final String right;
  final TextStyle style;
  final Color? rightColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            left,
            style: style,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          right,
          style: rightColor == null ? style : style.copyWith(color: rightColor),
        ),
      ],
    );
  }
}
