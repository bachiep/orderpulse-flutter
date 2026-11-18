import 'package:flutter/material.dart';
import 'package:orderpulse_flutter/core/theme/app_theme.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';

/// Confirmation dialog warning the chef when marking an order ready with unchecked prep items.
class UncheckedPrepGuardDialog extends StatelessWidget {
  const UncheckedPrepGuardDialog({
    super.key,
    required this.order,
  });

  final Order order;

  static Future<bool> show(BuildContext context, Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => UncheckedPrepGuardDialog(order: order),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final kds = KdsColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final uncheckedItems =
        order.items.where((item) => !item.isPrepped).toList(growable: false);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      icon: Icon(
        Icons.warning_amber_rounded,
        color: kds.statusNew,
        size: 32,
      ),
      title: const Text('Unchecked Prep Items'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${uncheckedItems.length} of ${order.totalLineCount} prep checklist item(s) on ${order.id} are not checked yet:',
              style: textTheme.bodySmall?.copyWith(color: kds.textSecondary),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kds.statusNewContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kds.statusNew.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: uncheckedItems
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• ${item.quantity}x ${item.name}',
                          style: textTheme.bodySmall?.copyWith(
                            color: kds.onStatusNewContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Review your prep checklist before handoff, or mark the ticket ready anyway.',
              style: textTheme.bodySmall?.copyWith(color: kds.textSecondary),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel / Review Items'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: kds.statusNew,
            foregroundColor: const Color(0xFF111827),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Mark Ready Anyway'),
        ),
      ],
    );
  }
}
