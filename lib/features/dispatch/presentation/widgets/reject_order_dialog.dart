import 'package:flutter/material.dart';

/// Keyboard-safe dialog requiring a non-empty rejection reason before rejecting an order.
class RejectOrderDialog extends StatefulWidget {
  const RejectOrderDialog({
    super.key,
    required this.orderId,
  });

  final String orderId;

  static Future<String?> show(BuildContext context, String orderId) {
    return showDialog<String>(
      context: context,
      builder: (_) => RejectOrderDialog(orderId: orderId),
    );
  }

  @override
  State<RejectOrderDialog> createState() => _RejectOrderDialogState();
}

class _RejectOrderDialogState extends State<RejectOrderDialog> {
  static const List<String> _presets = [
    'Item out of stock',
    'Kitchen overloaded',
    'Closing shift soon',
  ];

  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_reasonController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      title: Text('Reject ${widget.orderId}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Provide a clear reason for the customer and dispatch audit log.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _presets
                    .map(
                      (preset) => ActionChip(
                        label: Text(preset),
                        onPressed: () {
                          _reasonController.text = preset;
                        },
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reasonController,
                maxLines: 2,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Rejection reason',
                  hintText: 'e.g., Fresh seafood out of stock',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Rejection reason is required';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
          onPressed: _submit,
          child: const Text('Confirm Reject'),
        ),
      ],
    );
  }
}
