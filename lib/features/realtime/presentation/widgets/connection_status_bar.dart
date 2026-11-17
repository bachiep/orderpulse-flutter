import 'package:flutter/material.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    final (bg, fg, dotColor, label, showAction) = switch (state) {
      OrderStreamLive(:final receivedCount) => (
          isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
          isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
          const Color(0xFF10B981),
          receivedCount > 0
              ? 'Live • $receivedCount stream event(s)'
              : 'Live • Dispatch stream connected',
          false,
        ),
      OrderStreamConnecting() => (
          isDark ? const Color(0xFF134E4A) : const Color(0xFFCCFBF1),
          isDark ? const Color(0xFF5EEAD4) : const Color(0xFF115E59),
          const Color(0xFF14B8A6),
          'Connecting dispatch stream...',
          false,
        ),
      OrderStreamReconnecting(:final attempt, :final nextRetryDelay) => (
          isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
          isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E),
          const Color(0xFFF59E0B),
          'Reconnecting (attempt $attempt, retry in ${nextRetryDelay.inSeconds}s)...',
          true,
        ),
      OrderStreamOffline() => (
          isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
          isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
          const Color(0xFFEF4444),
          'Offline • Stream disconnected',
          true,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: bg,
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
              style: textTheme.labelMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showAction) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onReconnectTap,
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
          ],
        ],
      ),
    );
  }
}
