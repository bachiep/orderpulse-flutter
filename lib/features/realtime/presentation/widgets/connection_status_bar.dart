import 'package:flutter/material.dart';
import 'package:orderpulse_flutter/core/theme/app_theme.dart';
import 'package:orderpulse_flutter/features/realtime/presentation/bloc/order_stream_bloc.dart';

/// Compact realtime stream banner displaying Live / Reconnecting / Offline state.
class ConnectionStatusBar extends StatelessWidget {
  const ConnectionStatusBar({
    super.key,
    required this.state,
    required this.onReconnectTap,
  });

  final OrderStreamState state;
  final VoidCallback onReconnectTap;

  @override
  Widget build(BuildContext context) {
    final kds = KdsColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    final (bg, fg, dotColor, label, showAction) = switch (state) {
      OrderStreamLive(:final receivedCount) => (
          kds.statusReadyContainer,
          kds.onStatusReadyContainer,
          kds.statusReady,
          receivedCount > 0
              ? 'Live • $receivedCount stream event(s)'
              : 'Live • Dispatch stream connected',
          false,
        ),
      OrderStreamConnecting() => (
          kds.statusPreparingContainer,
          kds.onStatusPreparingContainer,
          kds.statusPreparing,
          'Connecting dispatch stream...',
          false,
        ),
      OrderStreamReconnecting(:final attempt, :final nextRetryDelay) => (
          kds.statusNewContainer,
          kds.onStatusNewContainer,
          kds.statusNew,
          'Reconnecting (attempt $attempt, retry in ${nextRetryDelay.inSeconds}s)...',
          true,
        ),
      OrderStreamOffline() => (
          kds.statusRejectedContainer,
          kds.onStatusRejectedContainer,
          kds.statusRejected,
          'Offline • Stream disconnected',
          true,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: kds.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: tabularStyle(
                textTheme.labelMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showAction) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onReconnectTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  'Reconnect',
                  style: textTheme.labelMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: fg,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
